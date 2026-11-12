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

// ebsSetupMountDir is where a new volume is mounted while existing data is copied onto it.
const ebsSetupMountDir = "/mnt/ebs-setup"

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
		// #nosec G204 // service is containerd.service or kubelet.service from dependentService
		_ = run(exec.Command("systemctl", "stop", service))
	}

	// Ensure target directory exists
	// #nosec G301 // mount targets and any missing parents must stay traversable by non-root users
	if err := os.MkdirAll(target, 0755); err != nil {
		return fmt.Errorf("failed to create mount target %s: %w", target, err)
	}

	// If the target has existing data and device is freshly formatted,
	// mount temporarily to copy data, then unmount
	if dirHasContent(target) {
		log.Info("Copying existing data to EBS volume", zap.String("target", target))
		if err := os.MkdirAll(ebsSetupMountDir, 0700); err != nil {
			return fmt.Errorf("failed to create temp mount dir: %w", err)
		}
		// #nosec G204 // program is fixed; the UUID and mount directory are passed as single arguments with no shell
		if err := run(exec.Command("mount", "UUID="+devUUID, ebsSetupMountDir)); err != nil {
			return fmt.Errorf("failed to temp mount: %w", err)
		}
		// #nosec G204 // program is fixed; target is passed as a single argument with no shell
		copyErr := run(exec.Command("cp", "-a", target+"/.", ebsSetupMountDir+"/"))
		unmountErr := run(exec.Command("umount", ebsSetupMountDir))
		if copyErr != nil {
			return fmt.Errorf("failed to copy data: %w", copyErr)
		}
		if unmountErr != nil {
			return fmt.Errorf("failed to unmount temp: %w", unmountErr)
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
	// #nosec G306 // systemd unit files are world-readable by convention and hold no secrets
	if err := os.WriteFile(unitPath, []byte(unitContent), 0644); err != nil {
		return fmt.Errorf("failed to write mount unit: %w", err)
	}

	// Enable and start the mount
	if err := run(exec.Command("systemctl", "daemon-reload")); err != nil {
		return fmt.Errorf("failed to reload systemd: %w", err)
	}
	// #nosec G204 // unit name is the systemd-escape output for the mount target
	if err := run(exec.Command("systemctl", "enable", mountUnitName, "--now")); err != nil {
		return fmt.Errorf("failed to enable mount unit %s: %w", mountUnitName, err)
	}

	// Restart the dependent service
	if service != "" {
		log.Info("Starting dependent service", zap.String("service", service))
		// #nosec G204 // service is containerd.service or kubelet.service from dependentService
		if err := run(exec.Command("systemctl", "start", service)); err != nil {
			return fmt.Errorf("failed to start %s: %w", service, err)
		}
	}

	log.Info("EBS volume mount complete", zap.String("target", target))
	return nil
}

func getFilesystemType(device string) (string, error) {
	// #nosec G204 // program is fixed; device is passed as a single argument with no shell
	out, err := exec.Command("lsblk", device, "-o", "fstype", "--noheadings").Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func getDeviceUUID(device string) (string, error) {
	// #nosec G204 // program is fixed; device is passed as a single argument with no shell
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
	// #nosec G204 // program is fixed; path is passed as a single argument with no shell, and systemd-escape only escapes it
	out, err := exec.Command("systemd-escape", "--path", "--suffix=mount", path).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func isUnitActive(unitName string) bool {
	// #nosec G204 // program and subcommand are fixed; unitName is passed as a single argument with no shell
	out, _ := exec.Command("systemctl", "is-active", unitName).Output()
	return strings.TrimSpace(string(out)) == "active"
}

func formatDevice(device string, fsType string) error {
	var cmd *exec.Cmd
	switch fsType {
	case "xfs":
		// #nosec G204 // program is fixed; device is passed as a single argument with no shell
		cmd = exec.Command("mkfs.xfs", device)
	case "ext4":
		// #nosec G204 // program is fixed; device is passed as a single argument with no shell
		cmd = exec.Command("mkfs.ext4", device)
	default:
		// #nosec G204 // program is fixed; fsType and device are passed as single arguments with no shell
		cmd = exec.Command("mkfs", "-t", fsType, device)
	}
	return run(cmd)
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

// run streams cmd's output to nodeadm's stdout and stderr and waits for it to finish.
func run(cmd *exec.Cmd) error {
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func validateEBSDevice(device string) error {
	// #nosec G204 // program is fixed; device is passed as a single argument with no shell
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
