package kubelet

import (
	"context"
	_ "embed"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	smithytime "github.com/aws/smithy-go/time"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/ipamd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

// default value from kubelet
// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration
const (
	defaultMaxPods = 110

	// maxPods padding to account for kube-proxy and the AWS VPC CNI,
	// host networking pods that do not claim IPs
	numHostNetworkingPods = 2

	// Limit on the percent of memory reserved for max pods. Can be overriden by
	// maxPodsHardFloor on some small instance sizes
	maxPercentMemoryReserved = 0.25

	// requires 299 (255 + 4*11) MB of memory, i.e. an instance with >=512 MB RAM.
	// intended to include host networking pods
	maxPodsHardFloor   = 4
	maxPodsHardCeiling = 737

	interrogationTimeout = 5 * time.Minute
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

func GetDefaultMaxPods(region string, instanceType string) int32 {
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

func projectMaxPodsFromMemoryMBReserved(memoryMB float64) int32 {
	return int32(math.Floor(float64(memoryMB)-255) / 11)
}

// boundedMaxPods adjusts the max pods values such that it satifies minimum, maximum, and
// memory constraints
func boundedMaxPods(maxPods int32) int32 {
	totalMem := int(system.GetTotalMemoryMB())
	ceiling := math.Min(float64(maxPods), float64(getMaxPodsCeiling(totalMem)))
	return int32(math.Max(ceiling, maxPodsHardFloor))
}

// getMaxPodsCeiling provides a basic ceiling to ensure that reserved max pods does not
// overconsume reserved memory, creating a diminishing effect on the number of schedulable pods.
// Limits the value so that the max pods use no more than 25% of memory, to a hard maximum of 737 pods.
func getMaxPodsCeiling(totalMemoryMB int) int32 {
	memoryMaxPodsCeiling := float64(projectMaxPodsFromMemoryMBReserved(float64(totalMemoryMB) * maxPercentMemoryReserved))
	return int32(math.Min(memoryMaxPodsCeiling, maxPodsHardCeiling))
}

func PollInterrogateMaxPods(ctx context.Context, maxDuration time.Duration, backoff time.Duration) (int32, error) {
	timedCtx, cancelTimedCtx := context.WithTimeout(ctx, maxDuration)
	defer cancelTimedCtx()
	for {
		maxPods, err := interrogateMaxPods()
		if err != nil {
			if ipamd.IsErrIPAMDNotReady(err) {
				// backoff and retry if IPAMD is not yet ready to serve responses
				if sleepErr := smithytime.SleepWithContext(timedCtx, backoff); sleepErr != nil {
					// bubble up the original error, not the context one
					return 0, err
				}
			} else {
				return 0, fmt.Errorf("unhandled error returned from interrogating max pods from the CNI: %v", err)
			}
		} else {
			return maxPods, err
		}
	}
}

// InterrogateMaxPods attempts to interrogate a locally running instance of ipamd for the maximum
// number of IPs it could allocate. ipamd is typically ran by a pod, so this will usually
// error if invoked at initial node bootstrap
func interrogateMaxPods() (int32, error) {
	maxIPs, err := ipamd.GetMaxAllocatableIPs()
	if err != nil {
		return 0, err
	} else if maxIPs <= 0 {
		return 0, fmt.Errorf("expected positive value for allocatable IPs, got %d", maxIPs)
	}
	return boundedMaxPods(maxIPs + numHostNetworkingPods), nil
}
