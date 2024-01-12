package kubelet

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
)

const KubeletDaemonName = "kubelet"

var _ daemon.Daemon = &kubelet{}

type kubelet struct {
	daemonManager daemon.DaemonManager
	environment   map[string]string
}

func NewKubeletDaemon(daemonManager daemon.DaemonManager) daemon.Daemon {
	return &kubelet{
		daemonManager: daemonManager,
		environment:   map[string]string{},
	}
}

func (k *kubelet) Configure(c *api.NodeConfig) error {
	if err := k.writeKubeletConfig(c); err != nil {
		return err
	}
	if err := k.writeKubeconfig(c); err != nil {
		return err
	}
	if err := writeClusterCaCert(c.Spec.Cluster.CertificateAuthority); err != nil {
		return err
	}
	if err := k.writeKubeletServiceEnvDropIn(c); err != nil {
		return err
	}
	return nil
}

func (k *kubelet) PostLaunch(c *api.NodeConfig) error {
	return nil
}

func (k *kubelet) EnsureRunning() error {
	return k.daemonManager.StartDaemon(KubeletDaemonName)
}

func (k *kubelet) Name() string {
	return KubeletDaemonName
}
