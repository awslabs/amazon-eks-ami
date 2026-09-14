package udev

import (
	"encoding/json"
	"path/filepath"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

// the MAC identifies the ENI that carried the interface name.
type managerCacheEntry struct {
	MAC     string `json:"mac"`
	Manager string `json:"manager"`
}

func decodeManagerCacheEntry(value string) (managerCacheEntry, error) {
	var entry managerCacheEntry
	err := json.Unmarshal([]byte(value), &entry)
	return entry, err
}

func writeManagerCacheEntry(cache util.FSCache, name, mac, manager string) error {
	data, err := json.Marshal(managerCacheEntry{MAC: mac, Manager: manager})
	if err != nil {
		return err
	}
	return cache.Write(name, string(data))
}

// CachedManagedInterfaces returns the systemd-managed names whose link still
// carries the cached MAC.
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
		if err != nil {
			return nil, err
		}
		entry, err := decodeManagerCacheEntry(value)
		if err != nil || entry.Manager != ManagerSystemd {
			continue
		}
		mac, err := interfaceMAC(name)
		if err != nil {
			zap.L().Info("skipping cached interface because of an error reading its address", zap.String("interface", name), zap.Error(err))
			continue
		}
		if entry.MAC != mac {
			zap.L().Info("ignoring cached ownership for a replaced interface", zap.String("interface", name), zap.String("mac", mac), zap.String("cachedMAC", entry.MAC))
			continue
		}
		managed = append(managed, name)
	}
	return managed, nil
}
