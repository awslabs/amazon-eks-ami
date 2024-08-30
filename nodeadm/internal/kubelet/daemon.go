package kubelet

import (
	"context"
	"fmt"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const KubeletDaemonName = "kubelet"

var _ daemon.Daemon = &kubelet{}

type kubelet struct {
	daemonManager daemon.DaemonManager
	// environment variables to write for kubelet
	environment map[string]string
	// kubelet config flags without leading dashes
	flags map[string]string
}

func NewKubeletDaemon(daemonManager daemon.DaemonManager) daemon.Daemon {
	return &kubelet{
		daemonManager: daemonManager,
		environment:   make(map[string]string),
		flags:         make(map[string]string),
	}
}

func (k *kubelet) Configure(cfg *api.NodeConfig) error {
	if err := k.writeKubeletConfig(cfg); err != nil {
		return err
	}
	if err := k.writeKubeconfig(cfg); err != nil {
		return err
	}
	if err := k.writeImageCredentialProviderConfig(cfg); err != nil {
		return err
	}
	if err := writeClusterCaCert(cfg.Spec.Cluster.CertificateAuthority); err != nil {
		return err
	}
	if err := k.writeKubeletEnvironment(cfg); err != nil {
		return err
	}
	return nil
}

func (k *kubelet) EnsureRunning(ctx context.Context) error {
	if err := k.daemonManager.StartDaemon(KubeletDaemonName); err != nil {
		return err
	}
	return util.NewRetrier(util.WithRetryAlways(), util.WithBackoffFixed(250*time.Millisecond)).Retry(ctx, func() error {
		status, err := k.daemonManager.GetDaemonStatus(KubeletDaemonName)
		if err != nil {
			return err
		}
		if status != daemon.DaemonStatusRunning {
			return fmt.Errorf("%s status is not %q", KubeletDaemonName, daemon.DaemonStatusRunning)
		}
		return nil
	})
}

func (k *kubelet) PostLaunch(_ *api.NodeConfig) error {
	return nil
}

func (k *kubelet) Name() string {
	return KubeletDaemonName
}
