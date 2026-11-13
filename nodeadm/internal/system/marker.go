package system

import (
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const markerPath = "/run/nodeadm/init"

// Created by kubelet.service ExecStartPre. Keep in sync with
// templates/*/runtime/rootfs/etc/systemd/system/kubelet.service.
const kubeletStartedMarkerPath = "/run/eks/kubelet/started"

// / Creates a marker file to indicate that nodeadm's run phase has been started.
func NewMarkerAspect() SystemAspect {
	return &markerAspect{}
}

type markerAspect struct{}

func MarkerPath() string {
	return markerPath
}

func KubeletStartedMarkerPath() string {
	return kubeletStartedMarkerPath
}

func (a *markerAspect) Name() string {
	return "marker"
}

func (a *markerAspect) Setup(*api.NodeConfig) error {
	if _, err := os.Stat("/run/cloud-init/result.json"); os.IsNotExist(err) {
		zap.L().Warn("cloud-init result file /run/cloud-init/result.json does not exist. Do not manually call nodeadm from user data")
	}

	// nodeadm is the only thing that should start kubelet, so kubelet having
	// started before the run phase means something else, like user data, did.
	if _, err := os.Stat(kubeletStartedMarkerPath); err == nil {
		zap.L().Warn("kubelet was started before nodeadm. Do not start or restart kubelet from user data",
			zap.String("docs", "https://github.com/awslabs/amazon-eks-ami/blob/main/nodeadm/doc/examples.md#configuring-kubelet"))
	}

	return util.WriteFileWithDir(markerPath, nil, 0644)
}
