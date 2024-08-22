package containerd

import (
	"slices"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
)

type instanceTypeMixin struct {
	instanceFamilies []string
	apply            func(*[]byte) error
}

func (m *instanceTypeMixin) matches(cfg *api.NodeConfig) bool {
	instanceFamily := strings.Split(cfg.Status.Instance.Type, ".")[0]
	return slices.Contains(m.instanceFamilies, instanceFamily)
}

var (
	// TODO: fetch this list dynamically
	nvidiaInstances         = []string{"p3", "p3dn", "p4d", "p4de", "p5", "g4", "g4dn", "g5", "g6"}
	NvidiaInstanceTypeMixin = instanceTypeMixin{
		instanceFamilies: nvidiaInstances,
		apply:            applyNvidia,
	}

	mixins = []instanceTypeMixin{
		NvidiaInstanceTypeMixin,
	}
)

// applyInstanceTypeMixins adds the needed OCI hook options to containerd config.toml
// based on the instance family
func applyInstanceTypeMixins(cfg *api.NodeConfig, containerdConfig *[]byte) error {
	for _, mixin := range mixins {
		if mixin.matches(cfg) {
			if err := mixin.apply(containerdConfig); err != nil {
				return err
			}
			return nil
		}
	}
	zap.L().Info("No containerd OCI configuration needed..", zap.String("instanceType", cfg.Status.Instance.Type))
	return nil
}

// applyNvidia adds the needed Nvidia containerd options
func applyNvidia(containerdConfig *[]byte) error {
	zap.L().Info("Configuring Nvidia OCI hook..")
	nvidiaOptions := `
[plugins.'io.containerd.grpc.v1.cri'.containerd]
default_runtime_name = 'nvidia'
discard_unpacked_layers = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
base_runtime_spec = "/etc/containerd/base-runtime-spec.json"
runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
BinaryName = "/usr/bin/nvidia-container-runtime"
SystemdCgroup = true
`

	if containerdConfig != nil {
		containerdConfigMap, err := util.Merge(*containerdConfig, []byte(nvidiaOptions), toml.Marshal, toml.Unmarshal)
		if err != nil {
			return err
		}
		*containerdConfig, err = toml.Marshal(containerdConfigMap)
		if err != nil {
			return err
		}
	}

	return nil
}
