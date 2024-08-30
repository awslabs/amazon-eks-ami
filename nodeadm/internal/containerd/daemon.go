package containerd

import (
	"context"
	"fmt"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
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

func (cd *containerd) Configure(c *api.NodeConfig) error {
	return writeContainerdConfig(c)
}

func (cd *containerd) EnsureRunning(ctx context.Context) error {
	if err := cd.daemonManager.StartDaemon(ContainerdDaemonName); err != nil {
		return err
	}
	return util.NewRetrier(util.WithRetryAlways(), util.WithBackoffFixed(250*time.Millisecond)).Retry(ctx, func() error {
		status, err := cd.daemonManager.GetDaemonStatus(ContainerdDaemonName)
		if err != nil {
			return err
		}
		if status != daemon.DaemonStatusRunning {
			return fmt.Errorf("%s status is not %q", ContainerdDaemonName, daemon.DaemonStatusRunning)
		}
		return nil
	})
}

func (cd *containerd) PostLaunch(c *api.NodeConfig) error {
	return cacheSandboxImage(c)
}

func (cd *containerd) Name() string {
	return ContainerdDaemonName
}
