package udev

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

// The instance ID scopes the directory; the MAC binds each named entry to the
// actual ENI. Keeping names as keys also lets the boot hook enumerate links.
type managerCacheEntry struct {
	MAC     string `json:"mac"`
	Manager string `json:"manager"`
}

func decodeManagerCacheEntry(value string) (managerCacheEntry, error) {
	// Legacy entries did not record identity. Preserve their ownership once on
	// upgrade, rather than reclassifying existing CNI links as boot interfaces.
	// The first broker read upgrades the entry with the current MAC. Historical
	// name reuse cannot be detected for these entries; new records are checked.
	if value == ManagerCNI || value == ManagerSystemd {
		return managerCacheEntry{Manager: value}, nil
	}
	var entry managerCacheEntry
	if err := json.Unmarshal([]byte(value), &entry); err != nil {
		return entry, fmt.Errorf("invalid network manager cache entry: %w", err)
	}
	if entry.MAC == "" || (entry.Manager != ManagerCNI && entry.Manager != ManagerSystemd) {
		return entry, fmt.Errorf("network manager cache entry has invalid identity or manager")
	}
	return entry, nil
}

func writeManagerCacheEntry(cache util.FSCache, name, mac, manager string) error {
	data, err := json.Marshal(managerCacheEntry{MAC: mac, Manager: manager})
	if err != nil {
		return err
	}
	return cache.Write(name, string(data))
}

// CachedManagedInterfaces returns only names still belonging to cached ENIs.
// The boot hook must not wait for a replacement ENI based on its predecessor.
func CachedManagedInterfaces(instanceID string) ([]string, error) {
	cache := util.NewFSCache(filepath.Join(NetworkManagerCacheDir, instanceID))
	return cachedManagedInterfaces(cache, getInterfaceMAC)
}

func cachedManagedInterfaces(cache util.FSCache, interfaceMAC func(string) (string, error)) ([]string, error) {
	names, err := cache.Keys()
	if err != nil {
		return nil, err
	}
	var managed []string
	for _, name := range names {
		value, err := cache.Read(name)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, err
		}
		entry, err := decodeManagerCacheEntry(value)
		if err != nil {
			return nil, err
		}
		if entry.Manager != ManagerSystemd {
			continue
		}
		mac, err := interfaceMAC(name)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, err
		}
		if entry.MAC != "" && entry.MAC != mac {
			zap.L().Info("ignoring cached ownership for a replaced interface", zap.String("interface", name), zap.String("mac", mac), zap.String("cachedMAC", entry.MAC))
			continue
		}
		managed = append(managed, name)
	}
	return managed, nil
}
