package util

import (
	"context"
	"fmt"
	"io"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
)

func ValidateNodeConfig(cfg *api.NodeConfig) error {
	if cfg.Spec.Cluster.Name == "" {
		return fmt.Errorf("Name is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.APIServerEndpoint == "" {
		return fmt.Errorf("Apiserver endpoint is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.CertificateAuthority == nil {
		return fmt.Errorf("Certificate authority is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.CIDR == "" {
		return fmt.Errorf("CIDR is missing in cluster configuration")
	}
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		if cfg.Spec.Cluster.ID == "" {
			return fmt.Errorf("CIDR is missing in cluster configuration")
		}
	}
	return nil
}

func DecodeNodeConfig(data []byte) (*api.NodeConfig, error) {
	return bridge.DecodeNodeConfig(data)
}

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
