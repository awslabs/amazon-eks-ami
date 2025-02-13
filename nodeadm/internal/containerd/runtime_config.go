package containerd

import (
	"slices"
	"strings"

	"go.uber.org/zap"
)

type instanceOptions struct {
	RuntimeName       string
	RuntimeBinaryName string
}

type instanceTypeMixin struct {
	instanceFamilies []string
	apply            func() instanceOptions
}

func (m *instanceTypeMixin) matches(instanceType string) bool {
	instanceFamily := strings.Split(instanceType, ".")[0]
	return slices.Contains(m.instanceFamilies, instanceFamily)
}

var (
	// TODO: fetch this list dynamically
	nvidiaInstances         = []string{"p3", "p3dn", "p4d", "p4de", "p5", "p5e", "p5en", "g4", "g4dn", "g5", "g6", "g6e", "g5g"}
	NvidiaInstanceTypeMixin = instanceTypeMixin{
		instanceFamilies: nvidiaInstances,
		apply:            applyNvidia,
	}

	mixins = []instanceTypeMixin{
		NvidiaInstanceTypeMixin,
	}
)

const nvidiaRuntimeName = "nvidia"
const nvidiaRuntimeBinaryName = "/usr/bin/nvidia-container-runtime"
const defaultRuntimeName = "runc"
const defaultRuntimeBinaryName = "/usr/sbin/runc"

// applyInstanceTypeMixins adds the needed OCI hook options to containerd config.toml
// based on the instance family
func applyInstanceTypeMixins(instanceType string) instanceOptions {
	for _, mixin := range mixins {
		if mixin.matches(instanceType) {
			return mixin.apply()
		}
	}
	zap.L().Info("No instance specific containerd runtime configuration needed..", zap.String("instanceType", instanceType))
	return applyDefault()
}

// applyNvidia adds the needed NVIDIA containerd options
func applyNvidia() instanceOptions {
	zap.L().Info("Configuring NVIDIA runtime..")
	return instanceOptions{RuntimeName: nvidiaRuntimeName, RuntimeBinaryName: nvidiaRuntimeBinaryName}
}

// applyDefault adds the default runc containerd options
func applyDefault() instanceOptions {
	zap.L().Info("Configuring default runtime..")
	return instanceOptions{RuntimeName: defaultRuntimeName, RuntimeBinaryName: defaultRuntimeBinaryName}
}
