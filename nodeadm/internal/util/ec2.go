package util

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/smithy-go/ptr"
)

type InstanceInfo struct {
	InstanceType              string `json:"instanceType"`
	DefaultMaxENIs            int32  `json:"defaultMaxENIs"`
	Ipv4AddressesPerInterface int32  `json:"ipv4AddressesPerInterface"`
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

func getInstanceInfoFromDescribeResponse(ec2Info types.InstanceTypeInfo) (InstanceInfo, error) {
	instanceType := string(ec2Info.InstanceType)
	var defaultMaxENIs *int32
	for _, networkCard := range ec2Info.NetworkInfo.NetworkCards {
		if aws.ToInt32(networkCard.NetworkCardIndex) == aws.ToInt32(ec2Info.NetworkInfo.DefaultNetworkCardIndex) {
			defaultMaxENIs = networkCard.MaximumNetworkInterfaces
			break
		}
	}
	if defaultMaxENIs == nil {
		return InstanceInfo{}, fmt.Errorf("failed to find maximum number of network interfaces on network card index %d for instance type %s", aws.ToInt32(ec2Info.NetworkInfo.DefaultNetworkCardIndex), instanceType)
	}
	if aws.ToInt32(defaultMaxENIs) <= 0 {
		return InstanceInfo{}, fmt.Errorf("found a non-positive value for the maximum number of interfaces supported on the network card index %d for instance type %s: %d", aws.ToInt32(ec2Info.NetworkInfo.DefaultNetworkCardIndex), instanceType, aws.ToInt32(defaultMaxENIs))
	}
	return InstanceInfo{
		InstanceType:              instanceType,
		DefaultMaxENIs:            aws.ToInt32(defaultMaxENIs),
		Ipv4AddressesPerInterface: ptr.ToInt32(ec2Info.NetworkInfo.Ipv4AddressesPerInterface),
	}, nil
}

func GetInstanceInfo(ctx context.Context, ec2API EC2API, instanceType string) (InstanceInfo, error) {
	describeResp, err := ec2API.DescribeInstanceTypes(ctx, &ec2.DescribeInstanceTypesInput{
		InstanceTypes: []types.InstanceType{types.InstanceType(instanceType)},
	})
	if err != nil {
		return InstanceInfo{}, fmt.Errorf("error describing instance type %s: %w", instanceType, err)
	}
	if describeResp == nil || len(describeResp.InstanceTypes) == 0 {
		return InstanceInfo{}, fmt.Errorf("no instance found for type: %s", instanceType)
	}
	return getInstanceInfoFromDescribeResponse(describeResp.InstanceTypes[0])
}

func GetGlobalSortedInstanceTypeInfo(ctx context.Context, cfg aws.Config) ([]InstanceInfo, error) {
	EC2Client := EC2Client{
		Client: ec2.NewFromConfig(cfg),
	}
	infoByInstanceType := make(map[string]InstanceInfo)
	regions, err := EC2Client.DescribeRegions(ctx)
	if err != nil {
		return nil, err
	}
	for _, region := range regions {
		if err := addInstanceTypeInfoFromRegion(ctx, cfg, region, infoByInstanceType); err != nil {
			return nil, err
		}
	}
	// call supplements at the end so that they act as overrides and it can be logged if they're redundant
	addInstanceTypeSupplements(infoByInstanceType)
	return getSortedInstanceTypeInfoFromMap(infoByInstanceType), nil
}

func getSortedInstanceTypeInfoFromMap(infoByInstanceType map[string]InstanceInfo) []InstanceInfo {
	var instanceTypesInfo []InstanceInfo
	for _, instanceTypeInfo := range infoByInstanceType {
		instanceTypesInfo = append(instanceTypesInfo, instanceTypeInfo)
	}
	sort.Slice(instanceTypesInfo, func(i, j int) bool {
		return strings.Compare(instanceTypesInfo[i].InstanceType, instanceTypesInfo[j].InstanceType) <= 0
	})
	return instanceTypesInfo
}

func (c *EC2Client) DescribeRegions(ctx context.Context) ([]string, error) {
	output, err := c.Client.DescribeRegions(ctx, &ec2.DescribeRegionsInput{})
	if err != nil {
		return []string{}, fmt.Errorf("failed to call EC2 DescribeRegions: %w", err)
	}

	var regionNames []string
	for _, region := range output.Regions {
		regionNames = append(regionNames, aws.ToString(region.RegionName))
	}
	sort.Strings(regionNames)
	return regionNames, nil
}

func addInstanceTypeInfoFromRegion(ctx context.Context, cfg aws.Config, region string, infoByInstanceType map[string]InstanceInfo) error {
	cfg.Region = region
	client := ec2.NewFromConfig(cfg)
	paginator := ec2.NewDescribeInstanceTypesPaginator(client, &ec2.DescribeInstanceTypesInput{})
	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return err
		}
		for _, instanceTypeResponse := range page.InstanceTypes {
			instanceInfo, err := getInstanceInfoFromDescribeResponse(instanceTypeResponse)
			if err != nil {
				return fmt.Errorf("failed to extract instance info for instance type %s in region %s: %v", instanceTypeResponse.InstanceType, region, instanceInfo)
			}
			infoByInstanceType[string(instanceTypeResponse.InstanceType)] = instanceInfo
		}
	}
	return nil
}

func addInstanceTypeSupplements(infoByInstanceType map[string]InstanceInfo) {
	// This list is not intended to be expanded, it exists solely to help in the migration from the legacy
	// eni-max-pods.txt file to the new JSON lines format. This list should only include all the instance
	// types that existed in the text file but were not discovered by default.
	// TODO: remove supplements as they become unnecessary
	supplementaryInfos := []InstanceInfo{
		{
			InstanceType:              "cr1.8xlarge",
			DefaultMaxENIs:            8,
			Ipv4AddressesPerInterface: 30,
		},
		{
			InstanceType:              "c5ad.metal",
			DefaultMaxENIs:            15,
			Ipv4AddressesPerInterface: 50,
		},
		{
			InstanceType:              "u-6tb1.metal",
			DefaultMaxENIs:            5,
			Ipv4AddressesPerInterface: 30,
		},
		{
			InstanceType:              "u-12tb1.metal",
			DefaultMaxENIs:            5,
			Ipv4AddressesPerInterface: 30,
		},
		{
			InstanceType:              "u-18tb1.metal",
			DefaultMaxENIs:            15,
			Ipv4AddressesPerInterface: 50,
		},
		{
			InstanceType:              "u-24tb1.metal",
			DefaultMaxENIs:            15,
			Ipv4AddressesPerInterface: 50,
		},
		{
			InstanceType:              "u-9tb1.metal",
			DefaultMaxENIs:            5,
			Ipv4AddressesPerInterface: 30,
		},
		{
			InstanceType:              "hs1.8xlarge",
			DefaultMaxENIs:            8,
			Ipv4AddressesPerInterface: 30,
		},
		{
			InstanceType:              "bmn-sf1.metal",
			DefaultMaxENIs:            15,
			Ipv4AddressesPerInterface: 50,
		},
		{
			InstanceType:              "c5a.metal",
			DefaultMaxENIs:            15,
			Ipv4AddressesPerInterface: 50,
		},
	}
	for _, supplementInfo := range supplementaryInfos {
		infoByInstanceType[string(supplementInfo.InstanceType)] = supplementInfo
	}
}
