package kubelet

import (
	"fmt"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	kubeletEnvironmentFilePath = "/etc/eks/kubelet/environment"
	kubeletArgsEnvironmentName = "NODEADM_KUBELET_ARGS"
)

// Write environment variables for kubelet execution
func (k *kubelet) writeKubeletEnvironment(cfg *api.NodeConfig) error {
	// transform kubelet additional arguments into a string and write them to
	// the kubelet args environment variable
	kubeletArgs := make([]string, len(k.additionalArguments))
	for flag, value := range k.additionalArguments {
		kubeletArgs = append(kubeletArgs, fmt.Sprintf("--%s=%s", flag, value))
	}
	kubeletEnvironment := []string{
		fmt.Sprintf("%s=%s", kubeletArgsEnvironmentName, strings.Join(kubeletArgs, " ")),
	}
	// write additional environment variables
	for eKey, eValue := range k.environment {
		kubeletEnvironment = append(kubeletEnvironment, fmt.Sprintf("%s=%s", eKey, eValue))
	}
	return util.WriteFileWithDir(kubeletEnvironmentFilePath, []byte(strings.Join(kubeletEnvironment, "\n")), kubeletConfigPerm)
}

// Add values to the environment variables map in a terse manner
func (k *kubelet) setEnv(envName string, envArg string) {
	k.environment[envName] = envArg
}
