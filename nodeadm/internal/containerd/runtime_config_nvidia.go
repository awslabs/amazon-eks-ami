package containerd

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const nvidiaRuntimeName = "nvidia"

func NewNvidiaRuntimeConfigMixin() *nvidiaRuntimeConfigMixin {
	return &nvidiaRuntimeConfigMixin{
		runtimeBinaryPath: util.NvidiaContainerRuntimeBinaryPath,
	}
}

type nvidiaRuntimeConfigMixin struct {
	runtimeBinaryPath string
}

func (m *nvidiaRuntimeConfigMixin) Matches(*api.NodeConfig) bool {
	// TODO: use nodeconfig data to discern if necessary.
	exists, _ := util.IsFilePathExists(m.runtimeBinaryPath)
	return exists
}

func (m *nvidiaRuntimeConfigMixin) Apply(opts *runtimeConfig) {
	zap.L().Info("Configuring NVIDIA runtime..")
	opts.RuntimeName = nvidiaRuntimeName
	opts.RuntimeBinaryPath = m.runtimeBinaryPath
}
