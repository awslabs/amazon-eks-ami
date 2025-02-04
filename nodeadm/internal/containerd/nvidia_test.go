package containerd

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
)

func TestNvidiaConfigurator(t *testing.T) {

	t.Run("IsNvidiaUsingInstanceType", func(t *testing.T) {
		configurator := nvidiaModifier{}
		template := containerdTemplateVars{}
		assert.True(t, configurator.Matches(nvidiaInstanceTypeNodeConfig("p5.48xlarge")))
		configurator.Modify(&template)
		assert.Equal(t, "nvidia", template.RuntimeName)
		assert.Equal(t, "/usr/bin/nvidia-container-runtime", template.RuntimeBinaryName)
	})

	t.Run("IsNvidiaUsingPCIe", func(t *testing.T) {
		configurator := nvidiaModifier{pcieDevicesPath: filepath.Join(t.TempDir(), "pcie-devices")}
		os.WriteFile(configurator.pcieDevicesPath, []byte("nvidia"), 0777)
		template := containerdTemplateVars{}
		assert.True(t, configurator.Matches(nvidiaInstanceTypeNodeConfig("xxx.xxxxx")))
		configurator.Modify(&template)
		assert.Equal(t, "nvidia", template.RuntimeName)
		assert.Equal(t, "/usr/bin/nvidia-container-runtime", template.RuntimeBinaryName)
	})

	t.Run("IsNotNvidia", func(t *testing.T) {
		configurator := nvidiaModifier{}
		assert.False(t, configurator.Matches(nvidiaInstanceTypeNodeConfig("m5.large")))
	})
}

func nvidiaInstanceTypeNodeConfig(instanceType string) *api.NodeConfig {
	return &api.NodeConfig{
		Status: api.NodeConfigStatus{
			Instance: api.InstanceDetails{
				Type: instanceType,
			},
		},
	}
}
