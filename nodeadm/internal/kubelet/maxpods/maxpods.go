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

const (
	// default value from kubelet
	// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
	DefaultMaxPods = 110

	memoryMiBRequiredPerPod = 11
	baseMemoryMiBRequirment = 255
)

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

// GetMaxPodsLimitForMemoryMiB returns a max pods limit value based on memory reserved
func GetMaxPodsLimitForMemoryMiB(reservableMemoryMiB uint64) int32 {
	maxMemMiBToReserve := getMaxMemoryMiBToReserve(reservableMemoryMiB)
	return projectMaxPodsFromMemoryMiBReserved(maxMemMiBToReserve)
}

// Allows memory reservations up to the following:
// 100% of the first 255 MiB
// 25% of the next 3,841 MiB (up to 4 GiB)
// 20% of the next 4 GiB (up to 8 GiB)
// 10% of the next 8 GiB (up to 16 GiB)
// 6% of the next 112 GiB (up to 128 GiB)
//
// Returns an int32 to match the expected type for maxPods
func getMaxMemoryMiBToReserve(memoryMiB uint64) int32 {
	percentsPerRange := []int{100, 25, 20, 10, 6}
	memoryBands := []int{0, 255, 4096, 8192, 16384, 131072}
	// #nosec G115 // value is limited by pre-defined bands and percents, so we know this cannot overflow
	return int32(util.GetAmountFromPercentageBands(percentsPerRange, memoryBands, memoryMiB, 100))
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
	return getMaxPodsFromENIInfo(eniInfo), nil
}

// projectMaxPodsFromMemoryMiBReserved back-calculates the number of pods calculated from a memory value,
// which is taken as a kubeReserved value. Accepts an int32 as a simplification to ensure that the (smaller)
// maxPods value satisfies the requirement of the type in the final kubelet configuration type
func projectMaxPodsFromMemoryMiBReserved(memoryMiB int32) int32 {
	maxPods := (memoryMiB - baseMemoryMiBRequirment) / memoryMiBRequiredPerPod
	return max(maxPods, 0)
}

func GetMemoryMebibytesToReserve(maxPods int32) int32 {
	return baseMemoryMiBRequirment + memoryMiBRequiredPerPod*maxPods
}

// getMaxPodsFromENIINfo should calcalate max pods in aligment with AL2, which essentially is
//
//	# of ENI * (# of IPv4 per ENI - 1) + 2
func getMaxPodsFromENIInfo(eniInfo util.EniInfo) int32 {
	return eniInfo.EniCount*(eniInfo.PodsPerEniCount-1) + 2
}
