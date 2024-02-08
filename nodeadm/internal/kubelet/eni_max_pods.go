package kubelet

import (
	"context"
	_ "embed"
	"fmt"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
	"strconv"
	"strings"
)

// default value from kubelet
// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
const defaultMaxPods = 110

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

// CalcMaxPods handle the edge case when instance type is not present in MaxPodsPerInstanceType
// The behavior should align with AL2:
// https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh#L514
// which essentially is
//
//	# of ENI * (# of IPv4 per ENI - 1) + 2
func CalcMaxPods(awsRegion string, instanceType string) int32 {
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		zap.L().Warn(fmt.Sprintf("error loading AWS SDK config when CalcMaxPods :%v \n defaulting maxPod to %d", err, defaultMaxPods))
		return defaultMaxPods
	}
	ec2Client := &util.EC2Client{Client: ec2.NewFromConfig(cfg)}
	eniInfo, err := util.GetEniInfoForInstanceType(ec2Client, instanceType)
	if err != nil {
		zap.L().Warn(fmt.Sprintf("Cannot find the max pod for %s, defaulting it to %d", instanceType, defaultMaxPods))
		return defaultMaxPods
	}
	return eniInfo.EniCount*(eniInfo.PodsPerEniCount-1) + 2
}
