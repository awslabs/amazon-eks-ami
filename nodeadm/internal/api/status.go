package api

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2extra "github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ec2"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"go.uber.org/zap"
)

// Fetch information about the ec2 instance using IMDS data.
// This information is stored into the internal config to avoid redundant calls
// to IMDS when looking for instance metadata
func GetInstanceDetails(ctx context.Context, featureGates map[Feature]bool, ec2Client *ec2.Client, imdsClient imds.IMDSClient) (*InstanceDetails, error) {
	instanceIdenitityDocument, err := imdsClient.GetInstanceIdentityDocument(ctx)
	if err != nil {
		return nil, err
	}

	mac, err := imdsClient.GetProperty(ctx, "mac")
	if err != nil {
		return nil, err
	}

	var privateDNSName string
	if !IsFeatureEnabled(InstanceIdNodeName, featureGates) {
		privateDNSName, err = getPrivateDNSName(ec2Client, instanceIdenitityDocument.InstanceID)
		if err != nil {
			return nil, err
		}
	}
	//	networkInterfaces, err := getNetworkInterfaceDetails(ctx, imdsClient)
	//	if err != nil {
	//		return nil, err
	//	}

	return &InstanceDetails{
		ID:               instanceIdenitityDocument.InstanceID,
		Region:           instanceIdenitityDocument.Region,
		Type:             instanceIdenitityDocument.InstanceType,
		AvailabilityZone: instanceIdenitityDocument.AvailabilityZone,
		MAC:              string(mac),
		PrivateDNSName:   privateDNSName,
		//		NetworkInterfaces: networkInterfaces,
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
	privateDNSName := aws.ToString(out.Reservations[0].Instances[0].PrivateDnsName)
	return privateDNSName, nil
}

func privateDNSNameAvailable(out *ec2.DescribeInstancesOutput) (bool, error) {
	if out == nil || len(out.Reservations) != 1 || len(out.Reservations[0].Instances) != 1 {
		return false, fmt.Errorf("reservation or instance not found")
	}
	return aws.ToString(out.Reservations[0].Instances[0].PrivateDnsName) != "", nil
}

func getNetworkInterfaceDetails(ctx context.Context, imdsClient imds.IMDSClient) ([]NetworkInterfaceDetails, error) {
	allMacs, err := imdsClient.GetProperty(ctx, imds.MACs)
	if err != nil {
		return nil, fmt.Errorf("failed to get network interfaces from imds: %w", err)
	}

	availableMacs := parseAvailableMacs(allMacs)

	var cards []NetworkInterfaceDetails
	for _, mac := range availableMacs {
		cardDetails, err := getNetworkInterfaceDetail(ctx, imdsClient, mac)
		if err != nil {
			if isNotFoundError(err) {
				zap.L().Info("ignoring 404 for network card", zap.String("MAC", mac))
				continue
			}
			return nil, fmt.Errorf("failed to get network card details for MAC %s: %w", mac, err)
		}
		// ip address can be empty for efa-only cards
		if cardDetails.IpV4Address == "" {
			zap.L().Info("ignoring EFA-only network card", zap.Reflect("cardDetails", cardDetails))
			continue
		}

		cards = append(cards, *cardDetails)
	}

	return cards, nil
}

func parseAvailableMacs(allMacs string) []string {
	allMacs = strings.ReplaceAll(allMacs, "\n", "")
	allMacs = strings.TrimSuffix(allMacs, "/")
	allMacs = strings.TrimSpace(allMacs)

	return strings.Split(allMacs, "/")
}

func getNetworkInterfaceDetail(ctx context.Context, imdsClient imds.IMDSClient, mac string) (*NetworkInterfaceDetails, error) {
	var details NetworkInterfaceDetails
	err := imds.MapProperties(ctx, imdsClient, &details, &struct {
		MAC string
	}{
		MAC: mac,
	})
	if err != nil {
		return nil, err
	}
	return &details, err
}

func isNotFoundError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "StatusCode: 404")
}
