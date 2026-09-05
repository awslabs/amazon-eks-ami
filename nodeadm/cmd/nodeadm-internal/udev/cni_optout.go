package udev

import (
	"context"
	"errors"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
)

// noManageTagKey opts an ENI out of VPC CNI management, leaving nodeadm
// responsible for configuring it.
//
// see: https://github.com/aws/amazon-vpc-cni-k8s/blob/5359e6b0ffaedae2bb831dceeea0337891c6f2ad/pkg/ipamd/ipamd.go#L129
const noManageTagKey = "node.k8s.amazonaws.com/no_manage"

type cniOptOutResolver interface {
	IsOptedOut(ctx context.Context, mac string) (bool, error)
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

// Missing tags are not a definitive CNI decision: EC2 may expose the ENI
// before its tags. Let systemd retry without persisting a negative result.
var errOwnershipUnknown = errors.New("ENI ownership tags not yet visible")

func (r *ec2TagResolver) IsOptedOut(ctx context.Context, mac string) (bool, error) {
	out, err := r.client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("mac-address"), Values: []string{mac}},
			// a MAC may have been reused elsewhere in the account/region.
			{Name: aws.String("attachment.instance-id"), Values: []string{r.instanceID}},
		},
	})
	if err != nil {
		return false, fmt.Errorf("failed to describe network interface for mac %s (check EC2 connectivity and ec2:DescribeNetworkInterfaces on the node role): %w", mac, err)
	}
	for _, eni := range out.NetworkInterfaces {
		for _, tag := range eni.TagSet {
			// IPAMD compares the value case-sensitively, so "True" stays
			// CNI-managed; adopting it would give the ENI two managers.
			//
			// see: https://github.com/aws/amazon-vpc-cni-k8s/blob/5359e6b0ffaedae2bb831dceeea0337891c6f2ad/pkg/ipamd/ipamd.go#L272
			if aws.ToString(tag.Key) == noManageTagKey {
				return aws.ToString(tag.Value) == "true", nil
			}
		}
	}
	return false, fmt.Errorf("mac %s: %w", mac, errOwnershipUnknown)
}
