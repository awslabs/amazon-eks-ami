package networkmanager

import (
	"encoding/json"
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

func DecodeCacheEntry(value string) (CacheEntry, error) {
	var entry CacheEntry
	err := json.Unmarshal([]byte(value), &entry)
	return entry, err
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
		value, err := cache.Read(name)
		if err != nil {
			return nil, err
		}
		entry, err := DecodeCacheEntry(value)
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

func InterfaceMAC(iface string) (string, error) {
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L34
	// #nosec G304 // read only operation on sysfs path
	macData, err := os.ReadFile(path.Join("/sys/class/net", iface, "address"))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(macData)), nil
}
