package kubelet

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/stretchr/testify/assert"
)

func TestKubeletCredentialProvidersFeatureFlag(t *testing.T) {
	var tests = []struct {
		kubeletVersion string
		expectedValue  *bool
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
