package maxpods

import (
	"context"
	_ "embed"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

// default value from kubelet
// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
const DefaultMaxPods = 110

//go:embed eni-max-pods.txt
var eniMaxPods string

var maxPodsPerInstanceType map[string]int

func init() {
	maxPodsPerInstanceType = make(map[string]int)
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

		maxPodsPerInstanceType[instanceType] = maxPods
	}
}

func projectMaxPodsFromMemoryMiBReserved(memoryMiB int32) int32 {
	return (memoryMiB - 255) / 11
}

// GetMaxPodsLimitForMemoryMiB returns a max pods limit value based on memory reserved
func GetMaxPodsLimitForMemoryMiB(memoryMiB uint64) int32 {
	percentsPerRange := []int{25, 20, 10, 6}
	memoryBands := []int{512, 4096, 8192, 16384, 131072}
	// #nosec G115 // value is limited by pre-defined bands and percents, so we know this cannot overflow
	memoryFromBands := int32(util.GetAmountFromPercentageBands(percentsPerRange, memoryBands, memoryMiB))
	maxReservable := 299 + memoryFromBands
	return projectMaxPodsFromMemoryMiBReserved(maxReservable)
}

func ApplyLimit(maxPods int32) int32 {
	totalMemory := system.GetTotalMemoryMiB()
	maxPodsLimit := GetMaxPodsLimitForMemoryMiB(totalMemory)
	return int32(math.Min(float64(maxPods), float64(maxPodsLimit)))
}

func GetENIMaxPodsFromFile(instanceType string) (int32, error) {
	if maxPods, ok := maxPodsPerInstanceType[instanceType]; ok {
		// #nosec G115 // known source from ec2 apis within int32 range
		return int32(maxPods), nil
	} else {
		return -1, fmt.Errorf("no local max pods value for instance type %q", instanceType)
	}
}

func GetENIMaxPodsFromEC2(awsRegion string, instanceType string) (int32, error) {
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		return -1, fmt.Errorf("error loading AWS SDK config when calculating max pods: %v", err)
	}
	ec2Client := &util.EC2Client{Client: ec2.NewFromConfig(cfg)}
	eniInfo, err := util.GetEniInfoForInstanceType(ec2Client, instanceType)
	if err != nil {
		return -1, fmt.Errorf("cannot find the max pod for instance type %q: %v", instanceType, err)
	}
	return getMaxPodsFromENIInfo(eniInfo.EniCount, eniInfo.PodsPerEniCount), nil
}

// getMaxPodsFromENIINfo should calcalate max pods in aligment with AL2, which essentially is
//
//	# of ENI * (# of IPv4 per ENI - 1) + 2
func getMaxPodsFromENIInfo(numENIs int32, podsPerENI int32) int32 {
	return numENIs*(podsPerENI-1) + 2
}
