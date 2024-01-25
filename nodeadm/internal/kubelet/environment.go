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

// Write environment variables needed for kubelet runtime. This should be the
// last method called on the kubelet object so that environment side effects of
// other methods are properly recored
func (k *kubelet) writeKubeletEnvironment(cfg *api.NodeConfig) error {
	// overwrite the kubelet cli arguments with flags specified by the user
	for flag, flagValue := range cfg.Spec.Kubelet.Flags {
		k.additionalArguments[flag] = flagValue
	}
	// transform kubelet arguments into a string and write them to the kubelet
	// environment variable
	var kubeletFlags []string
	for flag, value := range k.additionalArguments {
		kubeletFlags = append(kubeletFlags, fmt.Sprintf("--%s=%s", flag, value))
	}

	var kubeletEnvironment []string
	kubeletEnvironment = append(kubeletEnvironment, fmt.Sprintf("%s=%s", kubeletArgsEnvironmentName, strings.Join(kubeletFlags, " ")))
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
