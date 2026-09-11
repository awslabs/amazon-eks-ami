package udev

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
)

// noManageTagKey opts an ENI out of VPC CNI management. Nodeadm may adopt it
// only when OSManagedNoManageENIs is enabled and the link is eligible.
//
// see: https://github.com/aws/amazon-vpc-cni-k8s/blob/5359e6b0ffaedae2bb831dceeea0337891c6f2ad/pkg/ipamd/ipamd.go#L129
const noManageTagKey = "node.k8s.amazonaws.com/no_manage"

type ownershipDecision uint8

const (
	ownershipPending ownershipDecision = iota
	ownershipCNI
	ownershipSystemd
)

type cniOptOutResolver interface {
	Resolve(ctx context.Context, mac string) (ownershipDecision, error)
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
		// Bound wire attempts as well as elapsed time; outer ownership polling
		// supplies recovery after the SDK has exhausted this attempt's budget.
		client: ec2.NewFromConfig(cfg, func(o *ec2.Options) {
			o.RetryMaxAttempts = 3
		}),
		instanceID: instanceID,
	}, nil
}

// Resolve distinguishes incomplete visibility from an API failure. Neither is
// a definitive CNI decision, and neither may be cached as one.
func (r *ec2TagResolver) Resolve(ctx context.Context, mac string) (ownershipDecision, error) {
	out, err := r.client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("mac-address"), Values: []string{mac}},
			// a MAC may have been reused elsewhere in the account/region.
			{Name: aws.String("attachment.instance-id"), Values: []string{r.instanceID}},
		},
	})
	if err != nil {
		return ownershipPending, fmt.Errorf("failed to describe network interface for mac %s (check EC2 connectivity and ec2:DescribeNetworkInterfaces on the node role): %w", mac, err)
	}
	for _, eni := range out.NetworkInterfaces {
		for _, tag := range eni.TagSet {
			// IPAMD compares the value case-sensitively, so "True" stays
			// CNI-managed; adopting it would give the ENI two managers.
			//
			// see: https://github.com/aws/amazon-vpc-cni-k8s/blob/5359e6b0ffaedae2bb831dceeea0337891c6f2ad/pkg/ipamd/ipamd.go#L272
			if aws.ToString(tag.Key) == noManageTagKey {
				if aws.ToString(tag.Value) == "true" {
					return ownershipSystemd, nil
				}
				return ownershipCNI, nil
			}
		}
	}
	return ownershipPending, nil
}
