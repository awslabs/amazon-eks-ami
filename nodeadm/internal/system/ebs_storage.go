package system

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

const defaultFsType = "xfs"

func NewEBSStorageAspect() SystemAspect {
	return &ebsStorageAspect{}
}

type ebsStorageAspect struct{}

func (a *ebsStorageAspect) Name() string {
	return "ebs-storage"
}

func (a *ebsStorageAspect) Setup(cfg *api.NodeConfig) error {
	if len(cfg.Spec.Instance.Storage.Volumes) == 0 {
		zap.L().Info("No EBS storage volumes configured")
		return nil
	}

	// Validate no duplicate mount targets across all volumes
	seenTargets := make(map[string]string)
	for _, vol := range cfg.Spec.Instance.Storage.Volumes {
		if existingDevice, exists := seenTargets[vol.MountTarget]; exists {
			return fmt.Errorf("duplicate mount target %s: configured for both %s and %s", vol.MountTarget, existingDevice, vol.Device)
		}
		seenTargets[vol.MountTarget] = vol.Device
	}

	for _, vol := range cfg.Spec.Instance.Storage.Volumes {
		if err := a.setupVolume(vol); err != nil {
			return fmt.Errorf("failed to setup EBS volume %s: %w", vol.Device, err)
		}
	}
	return nil
}

func (a *ebsStorageAspect) setupVolume(vol api.VolumeMount) error {
	log := zap.L().With(zap.String("device", vol.Device))

	// Validate device exists
	if _, err := os.Stat(vol.Device); err != nil {
		return fmt.Errorf("device %s does not exist: %w", vol.Device, err)
	}

	// Validate device is an EBS volume
	if err := validateEBSDevice(vol.Device); err != nil {
		return err
	}

	fsType := vol.FsType
	if fsType == "" {
		fsType = defaultFsType
	}

	// Format the device if it has no filesystem
	currentFs, err := getFilesystemType(vol.Device)
	if err != nil {
		return fmt.Errorf("failed to detect filesystem on %s: %w", vol.Device, err)
	}
	if currentFs == "" {
		log.Info("Formatting EBS volume", zap.String("fsType", fsType))
		if err := formatDevice(vol.Device, fsType); err != nil {
			return fmt.Errorf("failed to format %s: %w", vol.Device, err)
		}
	} else {
		log.Info("EBS volume already formatted", zap.String("fsType", currentFs))
	}

	// Get the UUID of the formatted device for the systemd mount unit
	devUUID, err := getDeviceUUID(vol.Device)
	if err != nil {
		return fmt.Errorf("failed to get UUID for %s: %w", vol.Device, err)
	}

	if err := a.setupMountTarget(log, devUUID, vol.MountTarget, fsType); err != nil {
		return fmt.Errorf("failed to setup mount target %s: %w", vol.MountTarget, err)
	}
	return nil
}

func (a *ebsStorageAspect) setupMountTarget(log *zap.Logger, devUUID string, target string, fsType string) error {
	// Generate systemd mount unit name from the target path
	mountUnitName, err := systemdEscapePath(target)
	if err != nil {
		return fmt.Errorf("failed to escape path %s: %w", target, err)
	}

	// Check if the mount unit is already active (idempotent on reboot)
	if isUnitActive(mountUnitName) {
		log.Info("Mount unit already active, skipping", zap.String("target", target))
		return nil
	}

	// Stop the dependent service before copying data
	service := dependentService(target)
	if service != "" {
		log.Info("Stopping dependent service", zap.String("service", service))
		_ = runCommand("systemctl", "stop", service)
	}

	// Ensure target directory exists
	if err := os.MkdirAll(target, 0755); err != nil {
		return fmt.Errorf("failed to create mount target %s: %w", target, err)
	}

	// If the target has existing data and device is freshly formatted,
	// mount temporarily to copy data, then unmount
	if dirHasContent(target) {
		log.Info("Copying existing data to EBS volume", zap.String("target", target))
		tmpMount := "/mnt/ebs-setup"
		if err := os.MkdirAll(tmpMount, 0755); err != nil {
			return fmt.Errorf("failed to create temp mount dir: %w", err)
		}
		if err := runCommand("mount", "UUID="+devUUID, tmpMount); err != nil {
			return fmt.Errorf("failed to temp mount: %w", err)
		}
		if err := runCommand("cp", "-a", target+"/.", tmpMount+"/"); err != nil {
			_ = runCommand("umount", tmpMount)
			return fmt.Errorf("failed to copy data: %w", err)
		}
		if err := runCommand("umount", tmpMount); err != nil {
			return fmt.Errorf("failed to unmount temp: %w", err)
		}
	}

	// Create the systemd mount unit
	unitPath := fmt.Sprintf("/etc/systemd/system/%s", mountUnitName)
	unitContent := fmt.Sprintf(`[Unit]
Description=Mount EBS volume on %s

[Mount]
What=UUID=%s
Where=%s
Type=%s
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
`, target, devUUID, target, fsType)

	log.Info("Creating systemd mount unit", zap.String("unit", mountUnitName))
	if err := os.WriteFile(unitPath, []byte(unitContent), 0644); err != nil {
		return fmt.Errorf("failed to write mount unit: %w", err)
	}

	// Enable and start the mount
	if err := runCommand("systemctl", "daemon-reload"); err != nil {
		return fmt.Errorf("failed to reload systemd: %w", err)
	}
	if err := runCommand("systemctl", "enable", mountUnitName, "--now"); err != nil {
		return fmt.Errorf("failed to enable mount unit %s: %w", mountUnitName, err)
	}

	// Restart the dependent service
	if service != "" {
		log.Info("Starting dependent service", zap.String("service", service))
		if err := runCommand("systemctl", "start", service); err != nil {
			return fmt.Errorf("failed to start %s: %w", service, err)
		}
	}

	log.Info("EBS volume mount complete", zap.String("target", target))
	return nil
}

func getFilesystemType(device string) (string, error) {
	out, err := exec.Command("lsblk", device, "-o", "fstype", "--noheadings").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func getDeviceUUID(device string) (string, error) {
	out, err := exec.Command("blkid", "-s", "UUID", "-o", "value", device).Output()
	if err != nil {
		return "", err
	}
	uuid := strings.TrimSpace(string(out))
	if uuid == "" {
		return "", fmt.Errorf("no UUID found for device %s", device)
	}
	return uuid, nil
}

func systemdEscapePath(path string) (string, error) {
	out, err := exec.Command("systemd-escape", "--path", "--suffix=mount", path).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func isUnitActive(unitName string) bool {
	out, _ := exec.Command("systemctl", "is-active", unitName).Output()
	return strings.TrimSpace(string(out)) == "active"
}

func formatDevice(device string, fsType string) error {
	var cmd *exec.Cmd
	switch fsType {
	case "xfs":
		cmd = exec.Command("mkfs.xfs", device)
	case "ext4":
		cmd = exec.Command("mkfs.ext4", device)
	default:
		cmd = exec.Command("mkfs", "-t", fsType, device)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func dependentService(path string) string {
	switch path {
	case "/var/lib/containerd":
		return "containerd.service"
	case "/var/lib/kubelet":
		return "kubelet.service"
	default:
		return ""
	}
}

func dirHasContent(path string) bool {
	entries, err := os.ReadDir(path)
	if err != nil {
		return false
	}
	return len(entries) > 0
}

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func validateEBSDevice(device string) error {
	out, err := exec.Command("lsblk", device, "-o", "MODEL", "--noheadings").Output()
	if err != nil {
		return fmt.Errorf("failed to check device model for %s: %w", device, err)
	}
	model := strings.TrimSpace(string(out))
	if model != "Amazon Elastic Block Store" {
		return fmt.Errorf("device %s is not an EBS volume (model: %q)", device, model)
	}
	return nil
}
