package system

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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

	if err := validateVolumes(cfg.Spec.Instance.Storage.Volumes); err != nil {
		return err
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

	for _, target := range vol.BindTargets {
		if err := a.setupBindTarget(log, filepath.Clean(vol.MountTarget), filepath.Clean(target)); err != nil {
			return fmt.Errorf("failed to setup bind target %s: %w", target, err)
		}
	}
	return nil
}

// validateVolumes rejects configurations in which a directory is claimed more
// than once, whether as a mount target or as a bind target.
func validateVolumes(volumes []api.VolumeMount) error {
	seenTargets := make(map[string]string)
	claim := func(target string, device string) error {
		if existingDevice, exists := seenTargets[target]; exists {
			return fmt.Errorf("duplicate mount target %s: configured for both %s and %s", target, existingDevice, device)
		}
		seenTargets[target] = device
		return nil
	}

	for _, vol := range volumes {
		mountTarget := filepath.Clean(vol.MountTarget)
		if err := claim(mountTarget, vol.Device); err != nil {
			return err
		}

		seenSources := make(map[string]string)
		for _, target := range vol.BindTargets {
			if !filepath.IsAbs(target) || filepath.Clean(target) == "/" {
				return fmt.Errorf("bind target %q of %s must be an absolute path other than /", target, vol.Device)
			}
			target = filepath.Clean(target)
			if isWithin(target, mountTarget) || isWithin(mountTarget, target) {
				return fmt.Errorf("bind target %s of %s overlaps its mount target %s", target, vol.Device, mountTarget)
			}
			if err := claim(target, vol.Device); err != nil {
				return err
			}
			source := bindSource(mountTarget, target)
			if existingTarget, exists := seenSources[source]; exists {
				return fmt.Errorf("bind targets %s and %s of %s would share %s", existingTarget, target, vol.Device, source)
			}
			seenSources[source] = target
		}
	}
	return nil
}

// bindSource returns the directory on the volume that backs a bind target.
func bindSource(mountTarget string, target string) string {
	return filepath.Join(mountTarget, filepath.Base(target))
}

// isWithin reports whether path is dir or a descendant of it.
func isWithin(path string, dir string) bool {
	return path == dir || strings.HasPrefix(path, strings.TrimSuffix(dir, "/")+"/")
}

// setupBindTarget bind mounts target onto its subdirectory of the volume
// mounted at mountTarget, the same way setup-local-disks shares an instance
// store array between several directories.
func (a *ebsStorageAspect) setupBindTarget(log *zap.Logger, mountTarget string, target string) error {
	mountUnitName, err := systemdEscapePath(target)
	if err != nil {
		return fmt.Errorf("failed to escape path %s: %w", target, err)
	}
	volumeUnitName, err := systemdEscapePath(mountTarget)
	if err != nil {
		return fmt.Errorf("failed to escape path %s: %w", mountTarget, err)
	}

	// Check if the mount unit is already active (idempotent on reboot)
	if isUnitActive(mountUnitName) {
		log.Info("Bind mount unit already active, skipping", zap.String("target", target))
		return nil
	}

	// Stop the dependent service only if it is running, and start it again
	// only in that case, so daemons are not started ahead of nodeadm.
	service := dependentService(target)
	wasActive := service != "" && isUnitActive(service)
	if wasActive {
		log.Info("Stopping dependent service", zap.String("service", service))
		if err := runCommand("systemctl", "stop", service); err != nil {
			return fmt.Errorf("failed to stop %s: %w", service, err)
		}
	}

	source := bindSource(mountTarget, target)
	if err := os.MkdirAll(target, 0755); err != nil {
		return fmt.Errorf("failed to create bind target %s: %w", target, err)
	}
	if err := os.MkdirAll(source, 0755); err != nil {
		return fmt.Errorf("failed to create bind source %s: %w", source, err)
	}

	// Always copy, even an empty directory, so the source keeps the
	// target's ownership and mode.
	log.Info("Copying existing data to EBS volume", zap.String("target", target), zap.String("source", source))
	if err := runCommand("cp", "-a", target+"/.", source+"/"); err != nil {
		return fmt.Errorf("failed to copy data: %w", err)
	}

	unitPath := fmt.Sprintf("/etc/systemd/system/%s", mountUnitName)
	unitContent := fmt.Sprintf(`[Unit]
Description=Bind mount %s onto EBS volume at %s
Requires=%s
After=%s

[Mount]
What=%s
Where=%s
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
`, target, mountTarget, volumeUnitName, volumeUnitName, source, target)

	log.Info("Creating systemd bind mount unit", zap.String("unit", mountUnitName))
	if err := os.WriteFile(unitPath, []byte(unitContent), 0644); err != nil {
		return fmt.Errorf("failed to write mount unit: %w", err)
	}

	if err := runCommand("systemctl", "daemon-reload"); err != nil {
		return fmt.Errorf("failed to reload systemd: %w", err)
	}
	if err := runCommand("systemctl", "enable", mountUnitName, "--now"); err != nil {
		return fmt.Errorf("failed to enable mount unit %s: %w", mountUnitName, err)
	}

	if wasActive {
		log.Info("Starting dependent service", zap.String("service", service))
		if err := runCommand("systemctl", "start", service); err != nil {
			return fmt.Errorf("failed to start %s: %w", service, err)
		}
	}

	log.Info("EBS bind mount complete", zap.String("target", target), zap.String("source", source))
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
