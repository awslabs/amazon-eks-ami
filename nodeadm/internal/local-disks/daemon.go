package localdisks

import (
	"fmt"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
)

const LocalDisksDaemonName = "setup-local-disks"

var _ daemon.Daemon = &localDisks{}

type localDisks struct {
	daemonManager daemon.DaemonManager
}

func NewLocalDisksDaemon(daemonManager daemon.DaemonManager) daemon.Daemon {
	return &localDisks{
		daemonManager: daemonManager,
	}
}

func (ld *localDisks) Configure(c *api.NodeConfig) error {
	systemdUnitContent := fmt.Sprintf("[Service]\nEnvironment='MOUNT_TYPE=%s'", "raid0")
	return daemon.WriteSystemdServiceUnitDropIn(LocalDisksDaemonName, "00-environment.conf", systemdUnitContent, 0644)
}

func (ld *localDisks) PostLaunch(c *api.NodeConfig) error {
	return nil
}

func (ld *localDisks) EnsureRunning() error {
	return ld.daemonManager.StartDaemon(LocalDisksDaemonName)
}

func (ld *localDisks) Name() string {
	return LocalDisksDaemonName
}
