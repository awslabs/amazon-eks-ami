package udev

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/service/ec2"

	ec2extra "github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
)

// systemManagedTagKey marks an ENI to be configured by systemd-networkd.
const systemManagedTagKey = "alpha.node.eks.aws/system_managed"

type ownershipResolver interface {
	// Resolve returns the manager of the ENI with the given MAC, or an error
	// wrapping errOwnershipPending while the ENI or its tags are not visible.
	Resolve(ctx context.Context, mac string) (string, error)
}

type ec2TagResolver struct {
	imds   imds.IMDSClient
	client ec2.DescribeNetworkInterfacesAPIClient
}

func newEC2TagResolver(ctx context.Context) (*ec2TagResolver, error) {
	client, err := ec2extra.NewClient(ctx)
	if err != nil {
		return nil, err
	}
	return &ec2TagResolver{
		imds:   imds.DefaultClient(),
		client: client,
	}, nil
}

func (r *ec2TagResolver) Resolve(ctx context.Context, mac string) (string, error) {
	eniID, err := getInterfaceID(ctx, r.imds, mac)
	if err != nil {
		return "", fmt.Errorf("%w: failed to get network interface id for mac %s: %w", errOwnershipPending, mac, err)
	}
	tags, err := ec2extra.GetNetworkInterfaceTags(ctx, r.client, eniID)
	if err != nil {
		return "", fmt.Errorf("%w: %w", errOwnershipPending, err)
	}
	value, ok := tags[systemManagedTagKey]
	if !ok {
		return "", fmt.Errorf("%w: tags not yet visible for network interface %s", errOwnershipPending, eniID)
	}
	if value == "true" {
		return networkmanager.ManagerSystemd, nil
	}
	return networkmanager.ManagerCNI, nil
}
