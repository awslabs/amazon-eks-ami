package configprovider

import (
	"context"
	"io"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

// Fetch information about the ec2 instance using IMDS data.
// This information is stored into the internal config to avoid redundant calls
// to IMDS when looking for instance metadata
func FetchInstanceDetails() (*api.InstanceDetails, error) {
	imdsClient := imds.New(imds.Options{})
	instanceIdenitityDocument, err := imdsClient.GetInstanceIdentityDocument(context.TODO(), &imds.GetInstanceIdentityDocumentInput{})
	if err != nil {
		return nil, err
	}

	macResponse, err := imdsClient.GetMetadata(context.TODO(), &imds.GetMetadataInput{Path: "mac"})
	if err != nil {
		return nil, err
	}
	mac, err := io.ReadAll(macResponse.Content)
	if err != nil {
		return nil, err
	}

	instanceDetails := api.InstanceDetails{
		ID:               instanceIdenitityDocument.InstanceID,
		Region:           instanceIdenitityDocument.Region,
		Type:             instanceIdenitityDocument.InstanceType,
		AvailabilityZone: instanceIdenitityDocument.AvailabilityZone,
		MAC:              string(mac),
	}
	return &instanceDetails, nil
}
