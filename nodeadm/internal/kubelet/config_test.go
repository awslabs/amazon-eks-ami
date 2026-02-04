package kubelet

import (
	"context"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/stretchr/testify/assert"
)

func TestKubeletCredentialProvidersFeatureFlag(t *testing.T) {
	var tests = []struct {
		kubeletVersion string
		expectedValue  *bool
	}{
		{kubeletVersion: "v1.35.0"},
	}

	for _, test := range tests {
		kubeletConfig := defaultKubeletSubConfig()
		nodeConfig := api.NodeConfig{
			Status: api.NodeConfigStatus{
				KubeletVersion: test.kubeletVersion,
			},
		}
		kubeletConfig.withVersionToggles(&nodeConfig)
		assert.NotContainsf(t, kubeletConfig.FeatureGates, "KubeletCredentialProviders", "KubeletCredentialProviders shouldn't be set for versions %s", test.kubeletVersion)
	}
}

func TestContainerRuntime(t *testing.T) {
	var tests = []struct {
		kubeletVersion           string
		expectedContainerRuntime *string
	}{
		{kubeletVersion: "v1.28.0"},
	}

	for _, test := range tests {
		kubeletConfig := defaultKubeletSubConfig()
		nodeConfig := api.NodeConfig{
			Status: api.NodeConfigStatus{
				KubeletVersion: test.kubeletVersion,
			},
		}
		kubeletConfig.withVersionToggles(&nodeConfig)

		assert.Equal(t, containerd.ContainerRuntimeEndpoint, kubeletConfig.ContainerRuntimeEndpoint)
	}
}

func TestProviderID(t *testing.T) {
	var tests = []struct {
		kubeletVersion        string
		expectedCloudProvider string
	}{
		{kubeletVersion: "v1.28.0"},
		{kubeletVersion: "v1.33.0"},
	}

	nodeConfig := api.NodeConfig{
		Status: api.NodeConfigStatus{
			Instance: api.InstanceDetails{
				AvailabilityZone: "us-west-2f",
				ID:               "i-123456789000",
			},
		},
	}
	providerId := getProviderId(nodeConfig.Status.Instance.AvailabilityZone, nodeConfig.Status.Instance.ID)

	for _, test := range tests {
		kubeletArguments := make(map[string]string)
		kubeletConfig := defaultKubeletSubConfig()
		nodeConfig.Status.KubeletVersion = test.kubeletVersion
		kubeletConfig.withCloudProvider(&nodeConfig, kubeletArguments)
		assert.Equal(t, "external", kubeletArguments["cloud-provider"])
		assert.Equal(t, providerId, *kubeletConfig.ProviderID)
		// TODO assert that the --hostname-override == PrivateDnsName
	}
}

func TestMutableCSINodeAllocatableCountFeatureGate(t *testing.T) {
	tests := []struct {
		kubeletVersion string
		expected       bool
	}{
		{kubeletVersion: "v1.33.0", expected: false},
		{kubeletVersion: "v1.34.0", expected: true},
	}

	for _, test := range tests {
		kubeletConfig := defaultKubeletSubConfig()
		nodeConfig := api.NodeConfig{
			Status: api.NodeConfigStatus{
				KubeletVersion: test.kubeletVersion,
			},
		}
		kubeletConfig.withVersionToggles(&nodeConfig)
		if test.expected {
			assert.True(t, kubeletConfig.FeatureGates["MutableCSINodeAllocatableCount"])
		} else {
			assert.NotContains(t, kubeletConfig.FeatureGates, "MutableCSINodeAllocatableCount")
		}
	}
}

func TestGenerateKubeletConfig(t *testing.T) {
	mockIMDS := &imds.FakeIMDSClient{
		GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
			if prop == imds.LocalIPv4 {
				return "10.0.0.1", nil
			}
			return "", nil
		},
	}
	k := &kubelet{
		imdsClient:  mockIMDS,
		resources:   system.NewResources(system.FakeFileSystem{}),
		flags:       make(map[string]string),
		environment: make(map[string]string),
	}
	nodeConfig := &api.NodeConfig{
		Spec: api.NodeConfigSpec{
			Cluster: api.ClusterDetails{
				CIDR: "10.100.0.0/16",
			},
		},
		Status: api.NodeConfigStatus{
			KubeletVersion: "v1.33.0",
			Instance: api.InstanceDetails{
				AvailabilityZone: "us-west-2a",
				ID:               "i-1234567890abcdef0",
				PrivateDNSName:   "ip-10-0-0-1.us-west-2.compute.internal",
			},
		},
	}

	cfg, err := k.generateKubeletConfig(nodeConfig)
	assert.NoError(t, err)

	assert.Equal(t, "10.0.0.1", k.flags["node-ip"])
	assert.Equal(t, "external", k.flags["cloud-provider"])
	assert.Equal(t, "aws:///us-west-2a/i-1234567890abcdef0", *cfg.ProviderID)
}
