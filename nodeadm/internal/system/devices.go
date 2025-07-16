package system

import (
	"os"
	"path/filepath"
	"strings"

	"go.uber.org/zap"
)

const NVIDIA_VENDOR_ID = "0x10de"

// IsPCIVendorAttached returns whether any pcie devices with a given vendor id
// are attached to the instance.
func IsPCIVendorAttached(vendorId string) (bool, error) {
	vendorPaths, err := filepath.Glob("/sys/bus/pci/devices/*/vendor")
	if err != nil {
		return false, err
	}
	for _, vendorPath := range vendorPaths {
		// #nosec G304 // read only operation on sysfs path
		vendorIdBytes, err := os.ReadFile(vendorPath)
		if err != nil {
			zap.L().Warn("failed to read vendor id", zap.Error(err))
			continue
		}
		if strings.TrimSpace(string(vendorIdBytes)) == vendorId {
			return true, nil
		}
	}
	return false, nil
}
