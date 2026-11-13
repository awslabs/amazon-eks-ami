package udev

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/service/ec2"

	"github.com/awslabs/amazon-eks-ami/nodeadm/api/v1alpha1"
	ec2extra "github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
)

type ownershipResolver interface {
	// Resolve returns the manager of the ENI with the given MAC.
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
		// a new ENI's interface-id can 404 until IMDS catches up.
		imds:   imds.NewClient(imds.New(true)),
		client: client,
	}, nil
}

func (r *ec2TagResolver) Resolve(ctx context.Context, mac string) (string, error) {
	eniID, err := getInterfaceID(ctx, r.imds, mac)
	if err != nil {
		return "", fmt.Errorf("failed to get network interface id for mac %s: %w", mac, err)
	}
	tags, err := ec2extra.GetNetworkInterfaceTags(ctx, r.client, eniID)
	if err != nil {
		return "", err
	}
	if tags[v1alpha1.ENITagSystemManaged] == "true" {
		return networkmanager.ManagerSystemd, nil
	}
	return networkmanager.ManagerCNI, nil
}
