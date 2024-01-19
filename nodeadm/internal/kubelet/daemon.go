package kubelet

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
)

const KubeletDaemonName = "kubelet"

var _ daemon.Daemon = &kubelet{}

type kubelet struct {
	daemonManager       daemon.DaemonManager
	environment         map[string]string
	additionalArguments map[string]string
}

func NewKubeletDaemon(daemonManager daemon.DaemonManager) daemon.Daemon {
	return &kubelet{
		daemonManager:       daemonManager,
		environment:         make(map[string]string),
		additionalArguments: make(map[string]string),
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
	if err := k.writeKubeletServiceEnvDropIn(cfg); err != nil {
		return err
	}
	return nil
}

func (k *kubelet) EnsureRunning() error {
	return k.daemonManager.StartDaemon(KubeletDaemonName)
}

func (k *kubelet) PostLaunch(_ *api.NodeConfig) error {
	return nil
}

func (k *kubelet) Name() string {
	return KubeletDaemonName
}
