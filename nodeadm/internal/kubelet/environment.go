package kubelet

import (
	"fmt"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
)

const kubeletArgsEnvName = "KUBELET_ARGS"

// Write environment variables for kubelet execution to the systemd drop-in directory
func (k *kubelet) writeKubeletServiceEnvDropIn(c *api.NodeConfig) error {
	systemdUnitContent := "[Service]"

	// transform kubelet additional arguments into a string and write them to
	// the kubelet args environment variable
	kubeletArgs := make([]string, len(c.Spec.Kubelet.AdditionalArguments))
	for flag, value := range c.Spec.Kubelet.AdditionalArguments {
		kubeletArgs = append(kubeletArgs, fmt.Sprintf("--%s=%s", flag, value))
	}
	systemdUnitContent += fmt.Sprintf("\nEnvironment='%s=%s'", kubeletArgsEnvName, strings.Join(kubeletArgs, " "))

	// write additional environment variables
	for eKey, eValue := range k.environment {
		systemdUnitContent += fmt.Sprintf("\nEnvironment='%s=%s'", eKey, eValue)
	}

	return daemon.WriteSystemdServiceUnitDropIn(KubeletDaemonName, "00-environment.conf", systemdUnitContent, kubeletConfigPerm)
}

// Add values to the environment variables map in a terse manner
func (k *kubelet) setEnv(envName string, envArg string) {
	k.environment[envName] = envArg
}
