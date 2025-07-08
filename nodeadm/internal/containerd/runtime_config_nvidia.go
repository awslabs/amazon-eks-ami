package containerd

import (
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

const (
	nvidiaRuntimeName       = "nvidia"
	nvidiaRuntimeBinaryPath = "/usr/bin/nvidia-container-runtime"
)

func NewNvidiaRuntimeConfigMixin() *nvidiaRuntimeConfigMixin {
	return &nvidiaRuntimeConfigMixin{
		runtimeBinaryPath: nvidiaRuntimeBinaryPath,
	}
}

type nvidiaRuntimeConfigMixin struct {
	runtimeBinaryPath string
}

func (m *nvidiaRuntimeConfigMixin) Matches(*api.NodeConfig) bool {
	// TODO: use nodeconfig data to discern if necessary.
	_, err := os.Stat(m.runtimeBinaryPath)
	return err == nil
}

func (m *nvidiaRuntimeConfigMixin) Apply(opts *runtimeConfig) {
	zap.L().Info("Configuring NVIDIA runtime..")
	opts.RuntimeName = nvidiaRuntimeName
	opts.RuntimeBinaryPath = m.runtimeBinaryPath
}
