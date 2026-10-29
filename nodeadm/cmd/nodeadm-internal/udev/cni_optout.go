package udev

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"

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
	client     describeNetworkInterfacesAPI
	instanceID string
}

func newEC2TagResolver(ctx context.Context, instanceID string) (*ec2TagResolver, error) {
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithEC2IMDSRegion(func(o *config.UseEC2IMDSRegion) {
			o.Client = imds.New(true /* treat 404's as retryable */)
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}
	return &ec2TagResolver{
		client:     ec2.NewFromConfig(cfg),
		instanceID: instanceID,
	}, nil
}

func (r *ec2TagResolver) Resolve(ctx context.Context, mac string) (string, error) {
	out, err := r.client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("mac-address"), Values: []string{mac}},
			// MACs are not unique account-wide.
			{Name: aws.String("attachment.instance-id"), Values: []string{r.instanceID}},
		},
	})
	if err != nil {
		return "", fmt.Errorf("%w: failed to describe network interface for mac %s: %w", errOwnershipPending, mac, err)
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
	return "", fmt.Errorf("%w: tags not yet visible for mac %s", errOwnershipPending, mac)
}
