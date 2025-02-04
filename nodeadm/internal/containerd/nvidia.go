package containerd

import (
	"os"
	"slices"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

type nvidiaModifier struct {
	pcieDevicesPath string
}

func NewNvidiaModifier() *nvidiaModifier {
	return &nvidiaModifier{
		pcieDevicesPath: "/proc/bus/pci/devices",
	}
}

func (m *nvidiaModifier) Matches(cfg *api.NodeConfig) bool {
	return m.matchesInstanceType(cfg.Status.Instance.Type) || m.matchesPCIeVendor()
}

func (*nvidiaModifier) Modify(ctrdTemplate *containerdTemplateVars) {
	zap.L().Info("Configuring NVIDIA runtime..")
	ctrdTemplate.RuntimeName = "nvidia"
	ctrdTemplate.RuntimeBinaryName = "/usr/bin/nvidia-container-runtime"
}

var nvidiaInstanceFamilies = []string{
	"p3", "p3dn",
	"p4d", "p4de",
	"p5", "p5e", "p5en",
	"g4", "g4dn",
	"g5", "g5g",
	"g6", "g6e",
}

// TODO: deprecate to avoid manual instance type tracking.
func (*nvidiaModifier) matchesInstanceType(instanceType string) bool {
	family := strings.Split(instanceType, ".")[0]
	return slices.Contains(nvidiaInstanceFamilies, family)
}

func (m *nvidiaModifier) matchesPCIeVendor() bool {
	devices, err := os.ReadFile(m.pcieDevicesPath)
	if err != nil {
		zap.L().Error("Failed to read PCIe devices", zap.Error(err))
		return false
	}
	// The contents of '/proc/bus/pci/devices' looks like the following, where
	// the last column contains the vendor name if present.
	//
	// something like the following:
	//
	// 0018 1d0f1111 0 c1000008         0        0         0 0 0 c0002  400000        0      0       0 0 0 20000
	// 0020 1d0f8061 b c1508000         0        0         0 0 0     0    4000        0      0       0 0 0     0 nvme
	// 0028 1d0fec20 0 c1504000         0 c1400008         0 0 0     0    4000        0 100000       0 0 0     0 ena
	// 00f0 10de1eb8 a c0000000 44000000c        0 45000000c 0 0     0 1000000 10000000      0 2000000 0 0     0 nvidia
	// 00f8 1d0fcd01 0 c1500000         0 c150c008         0 0 0     0    4000        0   2000       0 0 0     0 nvme
	// 0030 1d0fec20 0 c1510000         0 c1600008         0 0 0     0    4000        0 100000       0 0 0     0 ena
	return strings.Contains(string(devices), "nvidia")
}
