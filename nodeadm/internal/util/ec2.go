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
	InstanceType              string            `json:"instanceType"`
	DefaultNetworkCardIndex   int32             `json:"defaultNetworkCardIndex"`
	NetworkCards              []NetworkCardInfo `json:"networkCardInfo"`
	Ipv4AddressesPerInterface int32             `json:"ipv4AddressesPerInterface"`
}

type NetworkCardInfo struct {
	NetworkCardIndex         int32 `json:"networkCardIndex"`
	MaximumNetworkInterfaces int32 `json:"maximumNetworkInterfaces"`
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

func getInstanceInfoFromDescribeResponse(ec2Info types.InstanceTypeInfo) InstanceInfo {
	var networkCards []NetworkCardInfo
	instanceType := string(ec2Info.InstanceType)
	for _, networkCard := range ec2Info.NetworkInfo.NetworkCards {
		networkCards = append(networkCards, NetworkCardInfo{
			NetworkCardIndex:         ptr.ToInt32(networkCard.NetworkCardIndex),
			MaximumNetworkInterfaces: ptr.ToInt32(networkCard.MaximumNetworkInterfaces),
		})
	}
	return InstanceInfo{
		InstanceType:              string(instanceType),
		NetworkCards:              networkCards,
		DefaultNetworkCardIndex:   ptr.ToInt32(ec2Info.NetworkInfo.DefaultNetworkCardIndex),
		Ipv4AddressesPerInterface: ptr.ToInt32(ec2Info.NetworkInfo.Ipv4AddressesPerInterface),
	}
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
	return getInstanceInfoFromDescribeResponse(describeResp.InstanceTypes[0]), nil
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
		regionNames = append(regionNames, *region.RegionName)
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
			infoByInstanceType[string(instanceTypeResponse.InstanceType)] = getInstanceInfoFromDescribeResponse(instanceTypeResponse)
		}
	}
	return nil
}
