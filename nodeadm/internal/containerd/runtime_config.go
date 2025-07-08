package containerd

import "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"

type runtimeConfig struct {
	RuntimeName       string
	RuntimeBinaryPath string
}

type runtimeConfigMixin interface {
	Apply(*runtimeConfig)
	Matches(*api.NodeConfig) bool
}

const (
	defaultRuntimeName       = "runc"
	defaultRuntimeBinaryPath = "/usr/sbin/runc"
)

var mixins = []runtimeConfigMixin{
	NewNvidiaRuntimeConfigMixin(),
}

// getRuntimeOptions adds the needed OCI hook options to containerd config.toml
// based on the instance family and available runtime binaries
func getRuntimeOptions(cfg *api.NodeConfig) runtimeConfig {
	options := runtimeConfig{
		RuntimeName:       defaultRuntimeName,
		RuntimeBinaryPath: defaultRuntimeBinaryPath,
	}
	for _, mixin := range mixins {
		if mixin.Matches(cfg) {
			mixin.Apply(&options)
		}
	}
	return options
}
