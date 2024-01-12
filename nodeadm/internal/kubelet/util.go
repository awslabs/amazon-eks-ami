package kubelet

import (
	"context"
	"math"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"golang.org/x/mod/semver"
)

func calculateMaxPods(instanceType, cniVersion string, cniCustomNetworking, cniPrefixDelegation bool, cniMaxEni int) (int, error) {
	const LowCpuMaxPodCeil = 110
	const HighCpuMaxPodCeil = 250
	const IpsPerPrefix = 16

	if cniMaxEni < 0 {
		cniMaxEni = math.MaxInt
	}

	ec2Client := ec2.New(ec2.Options{})
	describeInstanceTypesResponse, err := ec2Client.DescribeInstanceTypes(context.TODO(), &ec2.DescribeInstanceTypesInput{
		InstanceTypes: []types.InstanceType{types.InstanceType(instanceType)},
	})
	if err != nil {
		return 0, err
	}
	instanceTypeInfo := describeInstanceTypesResponse.InstanceTypes[0]

	prefixDelegationSupported := false
	if semver.Compare(cniVersion, "v1.8.0") > 0 {
		prefixDelegationSupported = true
	}

	podEniCount := int(math.Min(float64(cniMaxEni), float64(*instanceTypeInfo.NetworkInfo.MaximumNetworkInterfaces)))
	if cniCustomNetworking {
		podEniCount -= 1
	}

	instanceMaxEniIps := int(*instanceTypeInfo.NetworkInfo.Ipv4AddressesPerInterface)

	var maxPods int
	if instanceTypeInfo.Hypervisor == "nitro" && cniPrefixDelegation && prefixDelegationSupported {
		maxPods = podEniCount*((instanceMaxEniIps-1)*IpsPerPrefix) + 2
	} else {
		maxPods = podEniCount*(instanceMaxEniIps-1) + 2
	}

	cpuCount := *instanceTypeInfo.VCpuInfo.DefaultVCpus

	if cpuCount > 30 {
		return int(math.Min(HighCpuMaxPodCeil, float64(maxPods))), nil
	} else {
		return int(math.Min(LowCpuMaxPodCeil, float64(maxPods))), nil
	}
}
