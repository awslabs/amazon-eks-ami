package util

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

type InstanceTypeInfo struct {
	InstanceType                           string
	CPUCount                               int
	MemoryMB                               int
	DefaultNetworkCardsMaxpIPsPerInterface int
	DefaultNetworkCardMaxInterfaces        int
	Region                                 string
}

type EniInfo struct {
	EniCount        int32
	PodsPerEniCount int32
}

type EC2API interface {
	DescribeInstanceTypes(ctx context.Context, params *ec2.DescribeInstanceTypesInput, optFns ...func(*ec2.Options)) (*ec2.DescribeInstanceTypesOutput, error)
	DescribeRegions(ctx context.Context) ([]string, error)
}

type EC2Client struct {
	Client *ec2.Client
}

func (c *EC2Client) DescribeInstanceTypes(ctx context.Context, params *ec2.DescribeInstanceTypesInput, optFns ...func(*ec2.Options)) (*ec2.DescribeInstanceTypesOutput, error) {
	return c.Client.DescribeInstanceTypes(ctx, params, optFns...)
}

func GetEniInfoForInstanceType(ec2API EC2API, instanceType string) (EniInfo, error) {
	describeResp, err := ec2API.DescribeInstanceTypes(context.Background(), &ec2.DescribeInstanceTypesInput{
		InstanceTypes: []types.InstanceType{types.InstanceType(instanceType)},
	})

	if err != nil {
		return EniInfo{}, fmt.Errorf("error describing instance type %s: %w", instanceType, err)
	}

	if len(describeResp.InstanceTypes) > 0 {
		instanceTypeInfo := describeResp.InstanceTypes[0]
		return EniInfo{
			EniCount:        *instanceTypeInfo.NetworkInfo.MaximumNetworkInterfaces,
			PodsPerEniCount: *instanceTypeInfo.NetworkInfo.Ipv4AddressesPerInterface,
		}, nil
	}
	return EniInfo{}, fmt.Errorf("no instance found for type: %s", instanceType)
}

func GetGlobalSortedInstanceTypeInfo(ctx context.Context, cfg aws.Config) ([]InstanceTypeInfo, error) {
	EC2Client := EC2Client{
		Client: ec2.NewFromConfig(cfg),
	}
	infoByInstanceType := make(map[string]InstanceTypeInfo)
	// regions := []string{"us-west-2"}
	regions, err := EC2Client.DescribeRegions(ctx)
	if err != nil {
		return nil, err
	}
	for _, region := range regions {
		if err := addInstanceTypeInfoFromRegion(ctx, cfg, region, infoByInstanceType); err != nil {
			return nil, err
		}
	}
	return getSortedInstanceTypeInfoFromMap(infoByInstanceType), nil
}

func getSortedInstanceTypeInfoFromMap(infoByInstanceType map[string]InstanceTypeInfo) []InstanceTypeInfo {
	var instanceTypesInfo []InstanceTypeInfo
	for _, instanceTypeInfo := range infoByInstanceType {
		instanceTypesInfo = append(instanceTypesInfo, instanceTypeInfo)
	}
	// sort increasing by instance type, alphabetically
	sort.Slice(instanceTypesInfo, func(i, j int) bool {
		return strings.Compare(instanceTypesInfo[i].InstanceType, instanceTypesInfo[j].InstanceType) <= 0
	})
	return instanceTypesInfo
}

func (c *EC2Client) DescribeRegions(ctx context.Context) ([]string, error) {
	output, err := c.Client.DescribeRegions(ctx, &ec2.DescribeRegionsInput{})
	if err != nil {
		return []string{}, fmt.Errorf("failed to call EC2 DescribeRegions: %v", err)
	}

	var regionNames []string
	for _, region := range output.Regions {
		regionNames = append(regionNames, *region.RegionName)
	}
	sort.Strings(regionNames)
	return regionNames, nil
}

func addInstanceTypeInfoFromRegion(ctx context.Context, cfg aws.Config, region string, infoByInstanceType map[string]InstanceTypeInfo) error {
	cfg.Region = region
	client := ec2.NewFromConfig(cfg)
	paginator := ec2.NewDescribeInstanceTypesPaginator(client, &ec2.DescribeInstanceTypesInput{
		// InstanceTypes: []types.InstanceType{"c1.xlarge", "c3.4xlarge", "c8gn.24xlarge", "m6i.4xlarge", "r6idn.2xlarge", "t3.nano", "u7in-32tb.224xlarge"},
	})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return err
		}
		for _, instanceTypeResponse := range page.InstanceTypes {
			instanceType := string(instanceTypeResponse.InstanceType)
			defaultNetworkCard := int(aws.ToInt32(instanceTypeResponse.NetworkInfo.DefaultNetworkCardIndex))
			infoByInstanceType[string(instanceTypeResponse.InstanceType)] = InstanceTypeInfo{
				InstanceType:                           string(instanceType),
				CPUCount:                               int(aws.ToInt32(instanceTypeResponse.VCpuInfo.DefaultVCpus)),
				MemoryMB:                               int(aws.ToInt64(instanceTypeResponse.MemoryInfo.SizeInMiB)),
				DefaultNetworkCardsMaxpIPsPerInterface: int(aws.ToInt32(instanceTypeResponse.NetworkInfo.Ipv4AddressesPerInterface)),
				DefaultNetworkCardMaxInterfaces:        int(aws.ToInt32(instanceTypeResponse.NetworkInfo.NetworkCards[defaultNetworkCard].MaximumNetworkInterfaces)),
				Region:                                 region,
			}
		}
	}
	return nil
}
