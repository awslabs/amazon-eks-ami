package containerd

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
)

const ContainerdDaemonName = "containerd"

var _ daemon.Daemon = &containerd{}

type containerd struct {
	daemonManager daemon.DaemonManager
}

func NewContainerdDaemon(daemonManager daemon.DaemonManager) daemon.Daemon {
	return &containerd{
		daemonManager: daemonManager,
	}
}

func (cd *containerd) Configure(cfg *api.NodeConfig) error {
	if err := writeBaseRuntimeSpec(cfg); err != nil {
		return err
	}
	if err := writeSnapshotterConfig(cfg); err != nil {
		return err
	}
	return writeContainerdConfig(cfg)
}

func (cd *containerd) EnsureRunning() error {
	return cd.daemonManager.StartDaemon(ContainerdDaemonName)
}

func (cd *containerd) PostLaunch(cfg *api.NodeConfig) error {
	return nil
}

func (cd *containerd) Name() string {
	return ContainerdDaemonName
}
