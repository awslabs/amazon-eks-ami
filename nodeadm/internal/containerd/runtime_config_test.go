package containerd

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
)

func TestDefaultRuntimeOptions(t *testing.T) {
	expectedRuntimeConfig := runtimeConfig{
		RuntimeName:       defaultRuntimeName,
		RuntimeBinaryPath: defaultRuntimeBinaryPath,
	}
	actualRuntimeConfig := getRuntimeOptions(&api.NodeConfig{})

	assert.Equal(t, expectedRuntimeConfig, actualRuntimeConfig)
}

func TestNvidiaRuntimeOptionsMixin(t *testing.T) {
	mockNvidiaContainerRuntimePath := filepath.Join(t.TempDir(), "nvidia-container-runtime")
	_, err := os.Create(mockNvidiaContainerRuntimePath)
	assert.NoError(t, err)

	mixin := nvidiaRuntimeConfigMixin{runtimeBinaryPath: mockNvidiaContainerRuntimePath}
	expectedRuntimeConfig := runtimeConfig{
		RuntimeName:       nvidiaRuntimeName,
		RuntimeBinaryPath: mockNvidiaContainerRuntimePath,
	}
	assert.True(t, mixin.Matches(&api.NodeConfig{}))

	var actualRuntimeConfig runtimeConfig
	mixin.Apply(&actualRuntimeConfig)

	assert.Equal(t, expectedRuntimeConfig, actualRuntimeConfig)
}
