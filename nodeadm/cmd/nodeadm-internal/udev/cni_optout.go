package udev

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
)

// systemManagedTagKey marks an ENI to be configured by systemd-networkd.
const systemManagedTagKey = "alpha.node.eks.aws/system_managed"

type cniOptOutResolver interface {
	// Resolve returns the manager of the ENI with the given MAC, or an error
	// wrapping errOwnershipPending while the ENI or its tags are not visible.
	Resolve(ctx context.Context, mac string) (string, error)
}

type describeNetworkInterfacesAPI interface {
	DescribeNetworkInterfaces(ctx context.Context, params *ec2.DescribeNetworkInterfacesInput, optFns ...func(*ec2.Options)) (*ec2.DescribeNetworkInterfacesOutput, error)
}

type ec2TagResolver struct {
	imds   imds.IMDSClient
	client describeNetworkInterfacesAPI
}

func newEC2TagResolver(ctx context.Context) (*ec2TagResolver, error) {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithEC2IMDSRegion(func(o *config.UseEC2IMDSRegion) {
			o.Client = imds.New(true /* treat 404's as retryable */)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}
	return &ec2TagResolver{
		imds:   imds.DefaultClient(),
		client: ec2.NewFromConfig(cfg),
	}, nil
}

func (r *ec2TagResolver) Resolve(ctx context.Context, mac string) (string, error) {
	eniID, err := getInterfaceID(ctx, r.imds, mac)
	if err != nil {
		return "", fmt.Errorf("%w: failed to get network interface id for mac %s: %w", errOwnershipPending, mac, err)
	}
	out, err := r.client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		NetworkInterfaceIds: []string{eniID},
	})
	if err != nil {
		return "", fmt.Errorf("%w: failed to describe network interface %s: %w", errOwnershipPending, eniID, err)
	}
	for _, eni := range out.NetworkInterfaces {
		for _, tag := range eni.TagSet {
			if aws.ToString(tag.Key) == systemManagedTagKey {
				if aws.ToString(tag.Value) == "true" {
					return networkmanager.ManagerSystemd, nil
				}
				return networkmanager.ManagerCNI, nil
			}
		}
	}
	return "", fmt.Errorf("%w: tags not yet visible for network interface %s", errOwnershipPending, eniID)
}
