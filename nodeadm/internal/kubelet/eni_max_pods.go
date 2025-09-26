package kubelet

import (
	"bufio"
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"math"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/google/cel-go/cel"
	"github.com/google/cel-go/common/types"
	"go.uber.org/zap"
)

const (
	defaultENIsVar = "default_enis"
	ipsPerENIVar   = "ips_per_eni"
	maxPodsVar     = "max_pods"
)

// default value from kubelet
// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
const defaultMaxPods = 110

//go:embed instance-info.jsonl
var cachedInstanceInfoBytes []byte

func GetInstanceInfo(ctx context.Context, awsRegion string, instanceType string) (util.InstanceInfo, error) {
	// try to read it from the cached file first
	for s := bufio.NewScanner(bytes.NewReader(cachedInstanceInfoBytes)); s.Scan(); {
		var instanceInfo util.InstanceInfo
		if err := json.Unmarshal(s.Bytes(), &instanceInfo); err != nil {
			zap.L().Warn("Failed to read instance info line as json, searching in next line...", zap.Error(err))
			continue
		}
		if instanceInfo.InstanceType == instanceType {
			return instanceInfo, nil
		}
	}
	zap.L().Warn("Could not find instance info locally, making EC2 API call...", zap.String("instanceType", instanceType), zap.String("region", awsRegion))
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(awsRegion))
	if err != nil {
		return util.InstanceInfo{}, err
	}
	ec2Client := &util.EC2Client{Client: ec2.NewFromConfig(cfg)}
	return util.GetInstanceInfo(ctx, ec2Client, instanceType)
}

// Calcaultes a max pods value based on the provided instanceInfo and customExpression.
// If a custom expression is not set, the default behavior should align with AL2,
// which essentially is:
//
//	# of ENI on default network card * (# of IPv4 per ENI - 1) + 2
//
// TODO: isolate this into a public-facing package for external use by other projects
func CalcMaxPods(instanceInfo util.InstanceInfo, customExpression string) int32 {
	standardMaxPods := calculateStandardMaxPods(instanceInfo)
	if len(customExpression) == 0 {
		return standardMaxPods
	}
	zap.L().Info("Applying custom max pods expression", zap.String("expression", customExpression))
	customMaxPods, err := evaluateCustomMaxPodsExpression(customExpression, instanceInfo, standardMaxPods)
	if err != nil {
		zap.L().Warn("Failed to evaluate custom expression, using standard max pods value", zap.Error(err))
		return standardMaxPods
	}
	return customMaxPods
}

func calculateStandardMaxPods(instanceInfo util.InstanceInfo) int32 {
	return instanceInfo.DefaultMaxENIs*(instanceInfo.Ipv4AddressesPerInterface-1) + 2
}

func evaluateCustomMaxPodsExpression(expression string, instanceInfo util.InstanceInfo, standardMaxPods int32) (int32, error) {
	env, err := cel.NewEnv(
		cel.Variable(defaultENIsVar, cel.IntType),
		cel.Variable(ipsPerENIVar, cel.IntType),
		cel.Variable(maxPodsVar, cel.IntType),
	)
	if err != nil {
		return -1, fmt.Errorf("failed to create environment for custom max pods expression: %w", err)
	}
	ast, issues := env.Compile(expression)
	if issues != nil {
		if issues.Err() != nil {
			return -1, fmt.Errorf("failed to compile custom max pods expression: %w", issues.Err())
		}
		zap.L().Warn("Encountered non-fatal issues compiling max pods expression", zap.String("issues", issues.String()))
	}
	program, err := env.Program(ast)
	if err != nil {
		return -1, fmt.Errorf("failed to form program from custom max pods expression: %w", err)
	}
	rawVal, _, err := program.Eval(map[string]interface{}{
		defaultENIsVar: instanceInfo.DefaultMaxENIs,
		ipsPerENIVar:   instanceInfo.Ipv4AddressesPerInterface,
		maxPodsVar:     standardMaxPods,
	})
	if castVal := rawVal.ConvertToType(cel.IntType); types.IsError(castVal) {
		return -1, fmt.Errorf("could not interpret result %q from evaluation of custom max pods expression as an integer: %w", rawVal.Value(), err)
	} else if int64Value, castOk := castVal.Value().(int64); !castOk {
		return -1, fmt.Errorf("could not cast %v from evaluation of custom max pods expression to an integer", int64Value)
	} else if int64Value > math.MaxInt32 || int64Value <= 0 {
		return -1, fmt.Errorf("max pods value %d from custom expression evaluation is invalid: value must be a positive integer less than %d", int64Value, math.MaxInt32)
	} else {
		// #nosec G115 // value must fit into an int32 based on the above check
		return int32(int64Value), nil
	}
}
