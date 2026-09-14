package containerd

import (
	"context"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
)

const ContainerdDaemonName = "containerd"

var _ daemon.Daemon = &containerd{}

type containerd struct {
	daemonManager daemon.DaemonManager
	resources     system.Resources
}

func NewContainerdDaemon(daemonManager daemon.DaemonManager, resources system.Resources) daemon.Daemon {
	return &containerd{
		daemonManager: daemonManager,
		resources:     resources,
	}
}

func (cd *containerd) Configure(ctx context.Context, c *api.NodeConfig) error {
	if err := writeBaseRuntimeSpec(c); err != nil {
		return err
	}
	if err := writeSnapshotterConfig(c, cd.resources); err != nil {
		return err
	}
	if err := writeContainerdConfig(c, cd.resources); err != nil {
		return err
	}
	if err := writeSOCIServiceDependency(ctx, c, cd.resources, cd.daemonManager); err != nil {
		return err
	}
	return nil
}

func (cd *containerd) EnsureRunning(ctx context.Context) error {
	return cd.daemonManager.RestartDaemon(ctx, ContainerdDaemonName)
}

func (cd *containerd) PostLaunch(ctx context.Context, c *api.NodeConfig) error {
	if UseSOCISnapshotter(c, cd.resources) {
		if err := importSandboxImageForSOCI(ctx); err != nil {
			return err
		}
	}
	return nil
}

func (cd *containerd) Name() string {
	return ContainerdDaemonName
}
