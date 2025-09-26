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
	"github.com/aws/smithy-go/ptr"
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

var MaxPodsPerInstanceType map[string]int

func GetInstanceInfo(ctx context.Context, awsRegion string, instanceType string) (util.InstanceInfo, error) {
	// try to read it from the cached file first
	cachedInfoReader := bytes.NewReader(cachedInstanceInfoBytes)
	s := bufio.NewScanner(cachedInfoReader)
	for s.Scan() {
		var instanceInfo util.InstanceInfo
		if err := json.Unmarshal(s.Bytes(), &instanceInfo); err != nil {
			zap.L().Warn("failed to read instance info line as json, searching in next line...", zap.Error(err))
			continue
		}
		if instanceInfo.InstanceType == instanceType {
			return instanceInfo, nil
		}
	}
	zap.L().Warn("could not find instance info locally, attempting API request...", zap.String("instanceType", instanceType), zap.String("region", awsRegion))
	// fallback to making an API call if we could not load the value
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(awsRegion))
	if err != nil {
		return util.InstanceInfo{}, err
	}
	ec2Client := &util.EC2Client{Client: ec2.NewFromConfig(cfg)}
	resp, err := util.GetInstanceInfo(ctx, ec2Client, instanceType)
	return resp, err
}

// The default behavior should align with AL2, which essentially is:
//
//	# of ENI on default network card * (# of IPv4 per ENI - 1) + 2
func CalcMaxPods(awsRegion string, instanceType string, customExpression *string) int32 {
	instanceInfo, err := GetInstanceInfo(context.TODO(), awsRegion, instanceType)
	if err != nil {
		zap.L().Warn("could not find info for instance type, using default max pods value", zap.String("instanceType", instanceType), zap.Error(err))
		return defaultMaxPods
	}
	defaultMaxNetworkInterfaces, err := getDefaultMaxENIsFromInstanceInfo(instanceInfo)
	if err != nil {
		zap.L().Warn("could not determine the number of ENIs available on the default network card, using default max pods value", zap.Int32("numNetworkInterfaces", defaultMaxNetworkInterfaces))
		return defaultMaxPods
	}

	maxPods := calculateStandardMaxPods(defaultMaxNetworkInterfaces, instanceInfo.Ipv4AddressesPerInterface)
	if len(ptr.ToString(customExpression)) > 0 {
		zap.L().Info("applying custom max pods expression", zap.String("expression", ptr.ToString(customExpression)))
		if customVal, err := evaluateCustomMaxPodsExpression(ptr.ToString(customExpression), instanceInfo, maxPods); err == nil && customVal > 0 {
			maxPods = customVal
		} else {
			zap.L().Warn("failed to calculate max pods value with custom equation, using default value", zap.Error(err))
		}
	}
	return maxPods
}

func getDefaultMaxENIsFromInstanceInfo(instanceInfo util.InstanceInfo) (int32, error) {
	var err error
	defaultMaxNetworkInterfaces := int32(-1)
	for _, networkCard := range instanceInfo.NetworkCards {
		if networkCard.NetworkCardIndex == instanceInfo.DefaultNetworkCardIndex {
			defaultMaxNetworkInterfaces = networkCard.MaximumNetworkInterfaces
			break
		}
	}
	if defaultMaxNetworkInterfaces < 0 {
		return -1, fmt.Errorf("could not find default network card (index %d) in instance info: %+v", instanceInfo.DefaultNetworkCardIndex, instanceInfo)
	}
	return int32(defaultMaxNetworkInterfaces), err
}

func calculateStandardMaxPods(numENIs int32, IPsPerENI int32) int32 {
	return numENIs*(IPsPerENI-1) + 2
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
		} else {
			zap.L().Info("encountered non-fatal issues compiling max pods expression", zap.String("issues", issues.String()))
		}
	}
	program, err := env.Program(ast)
	if err != nil {
		return -1, fmt.Errorf("failed to form program from custom max pods expression: %w", err)
	}
	defaultMaxENIs, err := getDefaultMaxENIsFromInstanceInfo(instanceInfo)
	if err != nil {
		return -1, fmt.Errorf("could not determine the number of ENIs available on the default network card for custom max pods expression: %w", err)
	}
	rawVal, _, err := program.Eval(map[string]interface{}{
		defaultENIsVar: defaultMaxENIs,
		ipsPerENIVar:   instanceInfo.Ipv4AddressesPerInterface,
		maxPodsVar:     standardMaxPods,
	})
	castVal := rawVal.ConvertToType(cel.IntType)
	if types.IsError(castVal) {
		return -1, fmt.Errorf("could not cast result %q from evaluation of custom max pods expression to int: %w", rawVal.Value(), err)
	}
	int64Value := castVal.Value().(int64)
	if int64Value > math.MaxInt32 {
		return -1, fmt.Errorf("max pods value from custom expression is too large: %d", int64Value)
	}
	// #nosec G115 // value must fit into an int32 based on the above check
	return int32(int64Value), nil
}
