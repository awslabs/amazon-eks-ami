package containerd

import (
	"os"
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
	pcieDriverName   string
	pcieDevicesPath  string
}

func (m *instanceTypeMixin) matches(instanceType string) bool {
	instanceFamily := strings.Split(instanceType, ".")[0]
	return slices.Contains(m.instanceFamilies, instanceFamily) || m.matchesPCIeDriver()
}

// matchesPCIeDriver returns whether or not any PCIe devices are claimed by a
// driver that matches the driver name specified in the mixin.
func (m *instanceTypeMixin) matchesPCIeDriver() bool {
	if len(m.pcieDriverName) == 0 {
		return false
	}
	devices, err := os.ReadFile(m.pcieDevicesPath)
	if err != nil {
		zap.L().Error("Failed to read PCIe devices", zap.Error(err))
		return false
	}
	// for the implementation of '/proc/bus/pci/devices' in the linux kernel
	// see: https://elixir.bootlin.com/linux/v6.12.19/source/drivers/pci/proc.c#L367-L404
	// example:
	// 0018 1d0f1111 0 c1000008         0        0         0 0 0 c0002  400000        0      0       0 0 0 20000
	// 0020 1d0f8061 b c1508000         0        0         0 0 0     0    4000        0      0       0 0 0     0 nvme
	// 0028 1d0fec20 0 c1504000         0 c1400008         0 0 0     0    4000        0 100000       0 0 0     0 ena
	// 00f0 10de1eb8 a c0000000 44000000c        0 45000000c 0 0     0 1000000 10000000      0 2000000 0 0     0 nvidia
	// 00f8 1d0fcd01 0 c1500000         0 c150c008         0 0 0     0    4000        0   2000       0 0 0     0 nvme
	// 0030 1d0fec20 0 c1510000         0 c1600008         0 0 0     0    4000        0 100000       0 0 0     0 ena
	return strings.Contains(string(devices), m.pcieDriverName)
}

var (
	// TODO: fetch this list dynamically
	nvidiaInstances         = []string{"p3", "p3dn", "p4d", "p4de", "p5", "p5e", "p5en", "g4", "g4dn", "g5", "g6", "g6e"}
	NvidiaInstanceTypeMixin = instanceTypeMixin{
		instanceFamilies: nvidiaInstances,
		apply:            applyNvidia,
		pcieDriverName:   "nvidia",
		pcieDevicesPath:  "/proc/bus/pci/devices",
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
