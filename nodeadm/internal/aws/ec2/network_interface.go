package ec2

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
)

// NewClient returns an EC2 client for the region reported by IMDS.
func NewClient(ctx context.Context) (*ec2.Client, error) {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithEC2IMDSRegion(func(o *config.UseEC2IMDSRegion) {
			o.Client = imds.New(true /* treat 404's as retryable */)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}
	return ec2.NewFromConfig(cfg), nil
}

// GetNetworkInterfaceTags returns the tags of the network interface with the
// given ID.
func GetNetworkInterfaceTags(ctx context.Context, client ec2.DescribeNetworkInterfacesAPIClient, eniID string) (map[string]string, error) {
	out, err := client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		NetworkInterfaceIds: []string{eniID},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to describe network interface %s: %w", eniID, err)
	}
	tags := map[string]string{}
	for _, eni := range out.NetworkInterfaces {
		for _, tag := range eni.TagSet {
			tags[aws.ToString(tag.Key)] = aws.ToString(tag.Value)
		}
	}
	return tags, nil
}
