package system

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"go.uber.org/zap"
)

var (
	nodeDir  = "/sys/devices/system/node"
	cpusPath = "/sys/devices/system/cpu"
)

type Resources struct {
	fs FileSystem
}

func NewResources(fs FileSystem) Resources {
	return Resources{fs: fs}
}

const (
	memoryPath = "/sys/devices/system/memory"
)

func init() {
	// Cannot copy file to /sys for docker build, use this as a hack for e2e testing.
	cpuDirEnv := os.Getenv("CPU_DIR")
	if cpuDirEnv != "" {
		cpusPath = cpuDirEnv
	}
	nodeDirEnv := os.Getenv("NODE_DIR")
	if nodeDirEnv != "" {
		nodeDir = nodeDirEnv
	}
}

// GetMilliNumCores this is a very stripped version of GetNodesInfo that only get information for NumCores
// https://github.com/google/cadvisor/blob/master/utils/sysinfo/sysinfo.go#L203
func (r Resources) GetMilliNumCores() (int, error) {
	nodesPattern := filepath.Join(nodeDir, "node*[0-9]")
	nodesDirs, err := r.fs.Glob(nodesPattern)
	if err != nil {
		return 0, err
	}
	if len(nodesDirs) == 0 {
		zap.L().Error("Nodes topology is not available, providing CPU topology")
		cpuCount, err := r.getCPUCount()
		if err != nil {
			return 0, err
		}
		return cpuCount * 1000, nil
	}

	allLogicalCoresCount := 0
	for _, dir := range nodesDirs {
		cpuDirs, err := r.getCPUsPaths(dir)
		if err != nil {
			return 0, err
		}
		if len(cpuDirs) == 0 {
			zap.L().Error("Found node without any CPU", zap.String("dir", dir), zap.Error(err))
			continue
		}
		cores, err := r.getCoreCount(cpuDirs)
		if err != nil {
			return 0, err
		}
		allLogicalCoresCount += cores
	}
	return allLogicalCoresCount * 1000, err
}

func (r Resources) getCPUCount() (int, error) {
	cpusPaths, err := r.getCPUsPaths(cpusPath)
	if err != nil {
		return 0, err
	}
	cpusCount := len(cpusPaths)

	if cpusCount == 0 {
		return 0, fmt.Errorf("Any CPU is not available, cpusPath: %s", cpusPath)
	}
	return cpusCount, nil
}

func (r Resources) getCPUsPaths(cpusPath string) ([]string, error) {
	pathPattern := filepath.Join(cpusPath, "cpu*[0-9]")
	return r.fs.Glob(pathPattern)
}

func (r Resources) getCoreCount(cpuDirs []string) (int, error) {
	onlineCPUs, err := r.parseOnlineCPUs()
	if err != nil {
		return 0, fmt.Errorf("parsing online cpus: %w", err)
	}
	if len(onlineCPUs) == 0 {
		// This means all CPUs are online.
		return len(cpuDirs), nil
	}

	cores := 0
	for _, cpuDir := range cpuDirs {
		cpuID, err := getCPUID(cpuDir)
		if err != nil {
			return 0, fmt.Errorf("unexpected format of CPU directory: %w", err)
		}
		for _, cpuRange := range onlineCPUs {
			if cpuRange.start <= cpuID && cpuID <= cpuRange.end {
				cores++
				break
			}
		}
	}
	return cores, nil
}

func getCPUID(str string) (uint16, error) {
	base := filepath.Base(str)
	id, found := strings.CutPrefix(base, "cpu")
	if !found {
		return 0, fmt.Errorf("invalid CPUID string, base: %s, str: %s", base, str)
	}

	val, err := strconv.ParseUint(id, 10, 16)
	return uint16(val), err
}

type cpuRange struct {
	start uint16
	end   uint16
}

func (r Resources) parseOnlineCPUs() ([]cpuRange, error) {
	cpuOnlinePath := filepath.Join(cpusPath, "online")
	fileContent, err := r.fs.ReadFile(cpuOnlinePath)
	if os.IsNotExist(err) {
		// If file does not exist then kernel CPU hotplug is disabled and all CPUs are online.
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if len(fileContent) == 0 {
		// This shouldn't happen as cpu0 is always online.
		return nil, fmt.Errorf("%s found to be empty", cpuOnlinePath)
	}

	var ranges []cpuRange
	cpuList := strings.TrimSpace(string(fileContent))
	for s := range strings.SplitSeq(cpuList, ",") {
		splitted := strings.SplitN(s, "-", 3)
		switch len(splitted) {
		case 3:
			return nil, fmt.Errorf("invalid values in %s", cpuOnlinePath)
		case 2:
			min, err := strconv.ParseUint(splitted[0], 10, 16)
			if err != nil {
				return nil, err
			}
			max, err := strconv.ParseUint(splitted[1], 10, 16)
			if err != nil {
				return nil, err
			}
			if min > max {
				return nil, fmt.Errorf("invalid values in %s", cpuOnlinePath)
			}
			ranges = append(ranges, cpuRange{start: uint16(min), end: uint16(max)})
		case 1:
			value, err := strconv.ParseUint(s, 10, 16)
			if err != nil {
				return nil, err
			}
			ranges = append(ranges, cpuRange{start: uint16(value), end: uint16(value)})
		}
	}
	return ranges, nil
}

// Gets the total amount of online memory on the node in bytes.
func (r Resources) GetOnlineMemory() (int64, error) {
	blockSizePath := filepath.Join(memoryPath, "block_size_bytes")
	// #nosec G304 // This path is a constant sysfs path.
	blockSizeContents, err := r.fs.ReadFile(blockSizePath)
	if err != nil {
		return 0, fmt.Errorf("failed to read block size path '%s': %w", blockSizePath, err)
	}

	blockSize, err := strconv.ParseInt(strings.TrimSpace(string(blockSizeContents)), 16, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse block size '%s': %w", blockSizeContents, err)
	}

	files, err := r.fs.ReadDir(memoryPath)
	if err != nil {
		return 0, fmt.Errorf("failed to read memory dir '%s': %w", memoryPath, err)
	}

	onlineMemory := int64(0)
	pattern := regexp.MustCompile(`memory[0-9]+`)
	for _, file := range files {
		if !pattern.MatchString(file.Name()) {
			continue
		}

		onlinePath := filepath.Join(memoryPath, file.Name(), "online")
		// #nosec G304 // This path will be a sysfs subpath.
		onlineContents, err := r.fs.ReadFile(onlinePath)
		if err != nil {
			return 0, fmt.Errorf("failed to read online path for memory '%s': %w", onlinePath, err)
		}

		if strings.TrimSpace(string(onlineContents)) == "1" {
			onlineMemory += 1
		}
	}

	return blockSize * onlineMemory, nil
}
