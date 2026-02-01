package system

import (
	"bytes"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

var (
	//go:embed raid-mount.tpl
	raidMountTplData string
	raidMountTpl     = template.Must(template.New("raid-mount").Parse(raidMountTplData))

	//go:embed bind-mount.tpl
	bindMountTplData string
	bindMountTpl     = template.Must(template.New("bind-mount").Parse(bindMountTplData))

	//go:embed disk-mount.tpl
	diskMountTplData string
	diskMountTpl     = template.Must(template.New("disk-mount").Parse(diskMountTplData))
)

type raidMountVars struct {
	Level int
	UUID  string
	Where string
}

type bindMountVars struct {
	Level int
	What  string
	Where string
}

type diskMountVars struct {
	Index int
	What  string
	Where string
}

const (
	defaultMountDir = "/mnt/k8s-disks"
	mdConfigPath    = "/.aws/mdadm.conf"
	mdName          = "kubernetes"
)

func NewLocalDiskAspect() SystemAspect {
	return &localDiskAspect{}
}

type localDiskAspect struct{}

func (a *localDiskAspect) Name() string {
	return "local-disk"
}

func (a *localDiskAspect) Setup(cfg *api.NodeConfig) error {
	strategy := cfg.Spec.Instance.LocalStorage.Strategy
	if strategy == "" {
		zap.L().Info("Not configuring local disks!")
		return nil
	}

	if strategy != api.LocalStorageRAID0 && strategy != api.LocalStorageRAID10 && strategy != api.LocalStorageMount {
		return fmt.Errorf("invalid LocalStorage strategy: %s", strategy)
	}

	disks, err := findEphemeralDisks()
	if err != nil {
		return fmt.Errorf("finding ephemeral disks: %w", err)
	}
	if len(disks) == 0 {
		zap.L().Info("no NVMe instance storage disks found!")
		return nil
	}

	switch strategy {
	case api.LocalStorageRAID0:
		if err := setupRaid(0, disks, cfg); err != nil {
			return fmt.Errorf("setting up RAID0: %w", err)
		}
		zap.L().Info("Successfully setup RAID0", zap.Strings("disks", disks))
	case api.LocalStorageRAID10:
		if len(disks) < 4 {
			return fmt.Errorf("RAID10 requires at least 4 disks, but only %d found", len(disks))
		}

		if err := setupRaid(10, disks, cfg); err != nil {
			return fmt.Errorf("setting up RAID10: %w", err)
		}
		zap.L().Info("Successfully setup RAID10", zap.Strings("disks", disks))
	case api.LocalStorageMount:
		if err := setupMount(disks, cfg); err != nil {
			return fmt.Errorf("setting up disk mounts: %w", err)
		}
		zap.L().Info("Successfully setup disk mounts", zap.Strings("disks", disks))
	}
	return nil
}

func findEphemeralDisks() ([]string, error) {
	byIDPath := "/dev/disk/by-id/"
	entries, err := os.ReadDir(byIDPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return []string{}, nil
		}
		return nil, fmt.Errorf("reading %s: %w", byIDPath, err)
	}

	var disks []string
	for _, entry := range entries {
		if !strings.Contains(entry.Name(), "NVMe_Instance_Storage_") {
			continue
		}
		linkPath := filepath.Join(byIDPath, entry.Name())
		realPath, err := filepath.EvalSymlinks(linkPath)
		if err != nil {
			continue
		}
		disks = append(disks, realPath)
	}

	slices.Sort(disks)
	// Remove duplicates since by-id includes multiple references to the same disk.
	return slices.Compact(disks), nil
}

func getMountDir(cfg *api.NodeConfig) string {
	if cfg.Spec.Instance.LocalStorage.MountPath != "" {
		return cfg.Spec.Instance.LocalStorage.MountPath
	}
	return defaultMountDir
}

// Sets up a RAID-0 or RAID-10 of NVMe instance storage disks,
// moves contents and bind mounts directories
func setupRaid(level int, disks []string, cfg *api.NodeConfig) error {
	mdDevice := fmt.Sprintf("/dev/md/%s", mdName)
	arrayMountPoint := filepath.Join(getMountDir(cfg), "0")

	if err := os.MkdirAll(filepath.Dir(mdConfigPath), 0750); err != nil {
		return fmt.Errorf("creating mdadm config dir: %w", err)
	}

	if info, err := os.Stat(mdConfigPath); err != nil || info.Size() == 0 {
		args := []string{"--create", "--force", "--verbose", mdDevice,
			fmt.Sprintf("--level=%d", level), fmt.Sprintf("--name=%s", mdName),
			fmt.Sprintf("--raid-devices=%d", len(disks))}
		args = append(args, disks...)
		if err := runCmd("mdadm", args...); err != nil {
			return fmt.Errorf("creating RAID array: %w", err)
		}
		out, err := exec.Command("mdadm", "--detail", "--scan").Output()
		if err != nil {
			return fmt.Errorf("scanning RAID array: %w", err)
		}
		if err := os.WriteFile(mdConfigPath, out, 0600); err != nil {
			return fmt.Errorf("writing mdadm config: %w", err)
		}
	}
	// Do not wait for initial resync: raid0 has no redundancy so there
	// is no initial resync. Raid10 does not strictly needed a resync,
	// while the time taken for 4 1.9TB disk raid10 would be in range of
	// 20 minutes to 20 days, depending on dev.raid.speed_limit_min and
	// dev.raid.speed_limit_max sysctl parameters.

	// Check if the device symlink has changed on reboot to include a homehost identifier
	if entries, err := filepath.Glob(fmt.Sprintf("/dev/md/%s*", mdName)); err == nil && len(entries) > 0 {
		sort.Strings(entries)
		mdDevice = entries[len(entries)-1]
	}

	if !isFormatted(mdDevice) {
		// By default, mkfs tries to use the stripe unit of the array (512k),
		// for the log stripe unit, but the max log stripe unit is 256k.
		// So instead, we use 32k (8 blocks) to avoid a warning of breaching the max.
		// mkfs.xfs defaults to 32k after logging the warning since the default log buffer size is 32k.
		// Instances are delivered with disks fully trimmed, so TRIM is skipped at creation time.
		if err := runCmd("mkfs.xfs", "-K", "-l", "su=8b", mdDevice); err != nil {
			return fmt.Errorf("formatting %s: %w", mdDevice, err)
		}
	}

	if err := os.MkdirAll(arrayMountPoint, 0750); err != nil {
		return fmt.Errorf("creating mount point %s: %w", arrayMountPoint, err)
	}

	uuid, err := getBlkUUID(mdDevice)
	if err != nil {
		return fmt.Errorf("getting UUID for %s: %w", mdDevice, err)
	}

	mountUnit := systemdEscapePath(arrayMountPoint) + ".mount"
	var buf bytes.Buffer
	if err := raidMountTpl.Execute(&buf, raidMountVars{Level: level, UUID: uuid, Where: arrayMountPoint}); err != nil {
		return fmt.Errorf("rendering raid mount template: %w", err)
	}

	if err := writeAndEnableUnit(mountUnit, buf.Bytes()); err != nil {
		return fmt.Errorf("enabling mount unit %s: %w", mountUnit, err)
	}

	if err := setupBindMounts(level, arrayMountPoint, cfg); err != nil {
		return fmt.Errorf("setting up bind mounts: %w", err)
	}
	return nil
}

type bindMount struct {
	path          string
	dependentUnit string
}

func (bm *bindMount) mountUnit() string {
	return systemdEscapePath(bm.path) + ".mount"
}

func setupBindMounts(raidLevel int, arrayMountPoint string, cfg *api.NodeConfig) error {
	var bindMounts []bindMount
	disabled := cfg.Spec.Instance.LocalStorage.DisabledMounts
	if !slices.Contains(disabled, api.DisabledMountContainerd) {
		bindMounts = append(bindMounts, bindMount{"/var/lib/containerd", "containerd.service"})
	}
	if !slices.Contains(disabled, api.DisabledMountPodLogs) {
		bindMounts = append(bindMounts, bindMount{"/var/log/pods", "kubelet.service"})
	}
	if !slices.Contains(disabled, api.DisabledMountSOCI) {
		bindMounts = append(bindMounts, bindMount{"/var/lib/soci-snapshotter-grpc", "soci-snapshotter.service"})
	}
	// Kubelet is always bound (no DisabledMount constant for it)
	bindMounts = append(bindMounts, bindMount{"/var/lib/kubelet", "kubelet.service"})

	var prevRunning []string
	var needsLinking []bindMount
	for _, bm := range bindMounts {
		if isUnitActive(bm.mountUnit()) {
			continue
		}
		needsLinking = append(needsLinking, bm)
		if isUnitActive(bm.dependentUnit) {
			prevRunning = append(prevRunning, bm.dependentUnit)
		}

	}

	if len(prevRunning) > 0 {
		args := []string{"stop"}
		args = append(args, prevRunning...)
		err := runCmd("systemctl", args...)
		if err != nil {
			return fmt.Errorf("stopping units: %w", err)
		}
	}

	// Transfer state directories to the array, if they exist.
	for _, bm := range needsLinking {
		dir := filepath.Base(bm.path)
		arrayUnit := filepath.Join(arrayMountPoint, dir)
		if err := os.MkdirAll(bm.path, 0750); err != nil {
			return fmt.Errorf("creating directory %s: %w", bm.path, err)
		}
		zap.L().Info("Copying directory", zap.String("from", bm.path), zap.String("to", arrayUnit))
		if err := runCmd("cp", "-a", bm.path+"/", arrayUnit+"/"); err != nil {
			return fmt.Errorf("copying %s to %s: %w", bm.path, arrayUnit, err)
		}

		mountUnit := bm.mountUnit()
		var buf bytes.Buffer
		if err := bindMountTpl.Execute(&buf, bindMountVars{Level: raidLevel, What: arrayUnit, Where: bm.path}); err != nil {
			return fmt.Errorf("rendering bind mount template: %w", err)
		}

		if err := writeAndEnableUnit(mountUnit, buf.Bytes()); err != nil {
			return fmt.Errorf("enabling bind mount unit %s: %w", mountUnit, err)
		}
	}

	if len(prevRunning) > 0 {
		args := []string{"start"}
		args = append(args, prevRunning...)
		err := runCmd("systemctl", args...)
		if err != nil {
			return fmt.Errorf("restarting units: %w", err)
		}
	}
	return nil
}

// Mounts and creates xfs file systems on all EC2 instance store NVMe disks
// without existing file systems. Mounts in /mnt/k8s-disks/{1..} by default
func setupMount(disks []string, cfg *api.NodeConfig) error {
	mountDir := getMountDir(cfg)
	for idx, dev := range disks {
		if !isFormatted(dev) {
			if err := runCmd("mkfs.xfs", "-l", "su=8b", dev); err != nil {
				return fmt.Errorf("formatting %s: %w", dev, err)
			}
		}

		if isMounted(dev) {
			zap.L().Info("Device already mounted", zap.String("device", dev))
			continue
		}

		mp := filepath.Join(mountDir, fmt.Sprintf("%d", idx+1))
		if err := os.MkdirAll(mp, 0750); err != nil {
			return fmt.Errorf("creating mount point %s: %w", mp, err)
		}

		mountUnit := systemdEscapePath(mp)
		var buf bytes.Buffer
		if err := diskMountTpl.Execute(&buf, diskMountVars{Index: idx + 1, What: dev, Where: mp}); err != nil {
			return fmt.Errorf("rendering disk mount template: %w", err)
		}

		if err := writeAndEnableUnit(mountUnit+".mount", buf.Bytes()); err != nil {
			return fmt.Errorf("mount unit for %s: %w", dev, err)
		}
	}
	return nil
}

func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	var stderr bytes.Buffer
	cmd.Stdout = os.Stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%w: %s", err, stderr.String())
	}
	return nil
}

func isFormatted(dev string) bool {
	out, err := exec.Command("lsblk", dev, "-o", "fstype", "--noheadings").Output()
	return err == nil && strings.TrimSpace(string(out)) != ""
}

func isMounted(dev string) bool {
	out, err := exec.Command("lsblk", dev, "-o", "MOUNTPOINT", "--noheadings").Output()
	return err == nil && strings.TrimSpace(string(out)) != ""
}

func getBlkUUID(dev string) (string, error) {
	out, err := exec.Command("blkid", "-s", "UUID", "-o", "value", dev).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func systemdEscapePath(path string) string {
	// Handle root path
	if path == "/" {
		return "-"
	}
	// Remove leading, trailing, and collapse duplicate slashes
	path = filepath.Clean(path)
	path = strings.Trim(path, "/")
	if path == "" {
		return "-"
	}

	var result strings.Builder
	for i, c := range path {
		switch {
		case c == '/':
			result.WriteByte('-')
		case (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ':' || c == '_':
			result.WriteRune(c)
		case c == '.' && i != 0:
			result.WriteByte('.')
		default:
			fmt.Fprintf(&result, "\\x%02x", c)
		}
	}
	return result.String()
}

func isUnitActive(unit string) bool {
	err := exec.Command("systemctl", "is-active", unit).Run()
	return err == nil
}

func writeAndEnableUnit(unitName string, content []byte) error {
	unitPath := filepath.Join("/etc/systemd/system", unitName)
	if err := util.WriteFileWithDir(unitPath, content, 0644); err != nil {
		return fmt.Errorf("writing unit file: %w", err)
	}
	if err := runCmd("systemd-analyze", "verify", unitName); err != nil {
		return fmt.Errorf("verifying unit: %w", err)
	}
	if err := runCmd("systemctl", "enable", unitName, "--now"); err != nil {
		return fmt.Errorf("enabling unit: %w", err)
	}
	return nil
}
