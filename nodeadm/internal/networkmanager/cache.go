package networkmanager

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

// the MAC identifies the ENI that carried the interface name.
type CacheEntry struct {
	MAC     string `json:"mac"`
	Manager string `json:"manager"`
}

// ReadCacheEntry reports found=false only when the interface has no entry.
func ReadCacheEntry(cache util.FSCache, name string) (entry CacheEntry, found bool, err error) {
	value, err := cache.Read(name)
	if errors.Is(err, fs.ErrNotExist) {
		return CacheEntry{}, false, nil
	}
	if err != nil {
		return CacheEntry{}, false, err
	}
	if err := json.Unmarshal([]byte(value), &entry); err != nil {
		return CacheEntry{}, false, fmt.Errorf("failed to decode cache entry for %s: %w", name, err)
	}
	return entry, true, nil
}

func WriteCacheEntry(cache util.FSCache, name, mac, manager string) error {
	data, err := json.Marshal(CacheEntry{MAC: mac, Manager: manager})
	if err != nil {
		return err
	}
	return cache.Write(name, string(data))
}

// ManagedInterfaces returns the systemd-managed names whose link still carries
// the cached MAC.
func ManagedInterfaces(cache util.FSCache, interfaceMAC func(string) (string, error)) ([]string, error) {
	names, err := cache.Keys()
	if err != nil {
		return nil, err
	}
	var managed []string
	for _, name := range names {
		entry, found, err := ReadCacheEntry(cache, name)
		if err != nil {
			return nil, err
		}
		if !found || entry.Manager != ManagerSystemd {
			continue
		}
		mac, err := interfaceMAC(name)
		if errors.Is(err, fs.ErrNotExist) {
			zap.L().Info("skipping cached interface that no longer exists", zap.String("interface", name))
			continue
		}
		if err != nil {
			return nil, err
		}
		if entry.MAC != mac {
			zap.L().Info("ignoring cached ownership for a replaced interface", zap.String("interface", name), zap.String("mac", mac), zap.String("cachedMAC", entry.MAC))
			continue
		}
		managed = append(managed, name)
	}
	return managed, nil
}

func InterfaceMAC(iface string) (string, error) {
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L34
	// #nosec G304 // read only operation on sysfs path
	macData, err := os.ReadFile(path.Join("/sys/class/net", iface, "address"))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(macData)), nil
}
