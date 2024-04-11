package api

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go/aws"
	ec2extra "github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ec2"
)

// Fetch information about the ec2 instance using IMDS data.
// This information is stored into the internal config to avoid redundant calls
// to IMDS when looking for instance metadata
func GetInstanceDetails(ctx context.Context, featureGates map[Feature]bool, imdsClient *imds.Client, ec2Client *ec2.Client) (*InstanceDetails, error) {
	instanceIdenitityDocument, err := imdsClient.GetInstanceIdentityDocument(ctx, &imds.GetInstanceIdentityDocumentInput{})
	if err != nil {
		return nil, err
	}

	macResponse, err := imdsClient.GetMetadata(ctx, &imds.GetMetadataInput{Path: "mac"})
	if err != nil {
		return nil, err
	}
	mac, err := io.ReadAll(macResponse.Content)
	if err != nil {
		return nil, err
	}

	privateDNSName := ""
	if !IsFeatureEnabled(InstanceIdNodeName, featureGates) {
		privateDNSName, err = getPrivateDNSName(ec2Client, instanceIdenitityDocument.InstanceID)
		if err != nil {
			return nil, err
		}
	}

	return &InstanceDetails{
		ID:               instanceIdenitityDocument.InstanceID,
		Region:           instanceIdenitityDocument.Region,
		Type:             instanceIdenitityDocument.InstanceType,
		AvailabilityZone: instanceIdenitityDocument.AvailabilityZone,
		MAC:              string(mac),
		PrivateDNSName:   privateDNSName,
	}, nil
}

const privateDNSNameAvailableTimeout = 3 * time.Minute

// GetPrivateDNSName returns this instance's private DNS name as reported by the EC2 API, waiting until it's available if necessary.
func getPrivateDNSName(ec2Client *ec2.Client, instanceID string) (string, error) {
	w := ec2extra.NewInstanceConditionWaiter(ec2Client, privateDNSNameAvailable, func(opts *ec2extra.InstanceConditionWaiterOptions) {
		opts.LogWaitAttempts = true
	})
	out, err := w.WaitForOutput(context.TODO(), &ec2.DescribeInstancesInput{InstanceIds: []string{instanceID}}, privateDNSNameAvailableTimeout)
	if err != nil {
		return "", err
	}
	privateDNSName := aws.StringValue(out.Reservations[0].Instances[0].PrivateDnsName)
	return privateDNSName, nil
}

func privateDNSNameAvailable(out *ec2.DescribeInstancesOutput) (bool, error) {
	if out == nil || len(out.Reservations) != 1 || len(out.Reservations[0].Instances) != 1 {
		return false, fmt.Errorf("reservation or instance not found")
	}
	return aws.StringValue(out.Reservations[0].Instances[0].PrivateDnsName) != "", nil
}
