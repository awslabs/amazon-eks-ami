package featuregates

import (
	"encoding/base64"
	"fmt"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/eks"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

type FeatureGate = string

const (
	// When this flag is enabled, override the maxPods
	// value with a dynamic calculation of the eni limit using ec2 instance-type data
	ComputeMaxPods = FeatureGate("computeMaxPods")
	// When this flag is enabled, use a describe-cluster call
	// to repopulate all config data for ClusterDetails
	DescribeClusterDetails = FeatureGate("describeClusterDetails")
	// When this flag is enabled, override the kubelet
	// config with reserved cgroup values on behalf of the user
	DefaultReservedResources = FeatureGate("defaultReservedResources")
)

func DefaultTrue(featureGate FeatureGate, featureGates map[FeatureGate]bool) bool {
	enabled, set := featureGates[featureGate]
	return !set || enabled
}

func DefaultFalse(featureGate FeatureGate, featureGates map[FeatureGate]bool) bool {
	enabled, set := featureGates[featureGate]
	return set && enabled
}

// Discovers all cluster details using a describe call to the eks endpoint and
// updates the value of the config's `ClusterDetails` in-place
func PopulateClusterDetails(cfg *api.NodeConfig) error {
	// use instance region since cluster region isn't guarenteed to exist
	awsConfig := aws.NewConfig().WithRegion(cfg.Status.Instance.Region)
	eksClient := eks.New(session.Must(session.NewSession(awsConfig)))
	if err := eksClient.WaitUntilClusterActive(&eks.DescribeClusterInput{Name: &cfg.Spec.Cluster.Name}); err != nil {
		return err
	}
	describeResponse, err := eksClient.DescribeCluster(&eks.DescribeClusterInput{Name: &cfg.Spec.Cluster.Name})
	if err != nil {
		return err
	}

	ipFamily := *describeResponse.Cluster.KubernetesNetworkConfig.IpFamily

	var cidr string
	if ipFamily == eks.IpFamilyIpv4 {
		cidr = *describeResponse.Cluster.KubernetesNetworkConfig.ServiceIpv4Cidr
	} else if ipFamily == eks.IpFamilyIpv6 {
		cidr = *describeResponse.Cluster.KubernetesNetworkConfig.ServiceIpv6Cidr
	} else {
		return fmt.Errorf("bad ipFamily: %s", ipFamily)
	}

	isOutpost := false
	clusterId := cfg.Spec.Cluster.ID
	// detect whether the cluster is an aws outpost cluster depending on whether
	// the response contains the outpost ID
	if outpostId := describeResponse.Cluster.Id; outpostId != nil {
		clusterId = *outpostId
		isOutpost = true
	}

	enableOutpost := isOutpost
	// respect the user override for enabling the outpost
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil {
		enableOutpost = *enabled
	}

	caCert, err := base64.StdEncoding.DecodeString(*describeResponse.Cluster.CertificateAuthority.Data)
	if err != nil {
		return err
	}

	cfg.Spec.Cluster.APIServerEndpoint = *describeResponse.Cluster.Endpoint
	cfg.Spec.Cluster.CertificateAuthority = caCert
	cfg.Spec.Cluster.IPFamily = api.IPFamily(ipFamily)
	cfg.Spec.Cluster.CIDR = cidr
	cfg.Spec.Cluster.EnableOutpost = &enableOutpost
	cfg.Spec.Cluster.ID = clusterId

	return nil
}
