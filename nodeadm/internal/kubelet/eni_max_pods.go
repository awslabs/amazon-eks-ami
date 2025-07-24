package kubelet

import (
	"context"
	_ "embed"
	"fmt"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/ipamd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

// default value from kubelet
// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
const (
	defaultMaxPods = 110

	// numHostNetworkingPods is maxPods padding to account for expected host networking
	// pods that do not claim IPs: kube-proxy and the AWS VPC CNI
	numHostNetworkingPods = 2
)

//go:embed eni-max-pods.txt
var eniMaxPods string

var MaxPodsPerInstanceType map[string]int

func init() {
	MaxPodsPerInstanceType = make(map[string]int)
	lines := strings.Split(eniMaxPods, "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) != 2 {
			continue
		}

		instanceType := parts[0]
		maxPods, err := strconv.Atoi(parts[1])
		if err != nil {
			continue
		}

		MaxPodsPerInstanceType[instanceType] = maxPods
	}
}

func GetClassicMaxPods(region string, instanceType string) int32 {
	if maxPods, ok := MaxPodsPerInstanceType[instanceType]; ok {
		// #nosec G115 // known source from ec2 apis within int32 range
		return int32(maxPods)
	} else {
		return CalcMaxPods(region, instanceType)
	}
}

// CalcMaxPods handle the edge case when instance type is not present in MaxPodsPerInstanceType
// The behavior should align with AL2, which essentially is:
//
//	# of ENI * (# of IPv4 per ENI - 1) + 2
func CalcMaxPods(awsRegion string, instanceType string) int32 {
	zap.L().Info("calculate the max pod for instance type", zap.String("instanceType", instanceType))
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		zap.L().Warn("error loading AWS SDK config when calculating the max pod, setting it to default value", zap.Error(err))
		return defaultMaxPods
	}
	ec2Client := &util.EC2Client{Client: ec2.NewFromConfig(cfg)}
	eniInfo, err := util.GetEniInfoForInstanceType(ec2Client, instanceType)
	if err != nil {
		zap.L().Warn("cannot find the max pod for input instance type, setting it to default value")
		return defaultMaxPods
	}
	return eniInfo.EniCount*(eniInfo.PodsPerEniCount-1) + numHostNetworkingPods
}

// interrogateMaxPods attempts to interrogate a locally running instance of ipamd for the maximum
// number of IPs it could allocate. ipamd is typically ran by a pod, so this will usually
// error if invoked at initial node bootstrap.
//
// NOTE: this is a blocking call with a pre-configured timeout, the context should be appropriately set.
func interrogateMaxPods(ctx context.Context) (int32, error) {
	maxIPs, err := ipamd.PollMaxAllocatableIPs(ctx)
	if err != nil {
		return -1, err
	} else if maxIPs <= 0 {
		return -1, fmt.Errorf("expected positive value for allocatable IPs, got %d", maxIPs)
	}
	return maxIPs + numHostNetworkingPods, nil
}
