package udev

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/smithy-go"

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

// retryInterval paces retries while the ENI is not yet visible (EC2 eventual
// consistency); the caller's deadline bounds the total.
const retryInterval = 2 * time.Second

// ErrPermanentOptOutLookup marks a lookup failure retrying will not fix (e.g. a
// missing IAM permission); callers match on it to log an actionable diagnostic.
var ErrPermanentOptOutLookup = errors.New("permanent CNI opt-out lookup failure")

// permanentAPIErrorCodes will not resolve on retry. DescribeNetworkInterfaces
// models no error shapes, so failures surface as *smithy.GenericAPIError and
// can only be matched by code.
var permanentAPIErrorCodes = map[string]struct{}{
	"UnauthorizedOperation":       {},
	"AccessDenied":                {},
	"AccessDeniedException":       {},
	"AuthFailure":                 {},
	"UnauthorizedAccess":          {},
	"OptInRequired":               {},
	"InvalidParameterValue":       {},
	"InvalidParameterCombination": {},
	"MissingParameter":            {},
	"ValidationError":             {},
}

// classifyOptOutError annotates only known-unrecoverable codes; everything else
// (network, throttling, 5xx, unrecognized) stays unclassified for retry.
func classifyOptOutError(err error) error {
	var apiErr smithy.APIError
	if errors.As(err, &apiErr) {
		if _, ok := permanentAPIErrorCodes[apiErr.ErrorCode()]; ok {
			return fmt.Errorf("%w: %w", ErrPermanentOptOutLookup, err)
		}
	}
	return err
}

func (r *ec2TagResolver) IsOptedOut(ctx context.Context, mac string) (bool, error) {
	for {
		out, err := r.client.DescribeNetworkInterfaces(ctx, &ec2.DescribeNetworkInterfacesInput{
			Filters: []ec2types.Filter{
				{Name: aws.String("mac-address"), Values: []string{mac}},
				// a MAC may have been reused elsewhere in the account/region.
				{Name: aws.String("attachment.instance-id"), Values: []string{r.instanceID}},
			},
		})
		if err != nil {
			return false, classifyOptOutError(fmt.Errorf("failed to describe network interface for mac %s: %w", mac, err))
		}
		if len(out.NetworkInterfaces) == 0 {
			// ENI exists on the host but isn't yet visible via the eventually
			// consistent EC2 API; retry locally instead of consuming the unit's
			// restart budget.
			select {
			case <-ctx.Done():
				return false, fmt.Errorf("network interface for mac %s not yet visible via EC2 within deadline: %w", mac, ctx.Err())
			case <-time.After(retryInterval):
				continue
			}
		}
		for _, eni := range out.NetworkInterfaces {
			for _, tag := range eni.TagSet {
				// IPAMD compares the value case-sensitively, so "True" stays
				// CNI-managed; adopting it would give the ENI two managers.
				//
				// see: https://github.com/aws/amazon-vpc-cni-k8s/blob/5359e6b0ffaedae2bb831dceeea0337891c6f2ad/pkg/ipamd/ipamd.go#L272
				if aws.ToString(tag.Key) == noManageTagKey && aws.ToString(tag.Value) == "true" {
					return true, nil
				}
			}
		}
		return false, nil
	}
}
