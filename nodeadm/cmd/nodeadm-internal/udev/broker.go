package udev

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkInterfaceBroker interface {
	ManagerFor(interfaceName string) (string, error)
}

const NetworkManagerCacheDir = "/etc/eks/nodeadm/udev-net-manager"

type fsBroker struct {
	cache util.FSCache
}

func NewFSBroker(instanceID string) *fsBroker {
	return &fsBroker{
		cache: util.NewFSCache(filepath.Join(NetworkManagerCacheDir, instanceID)),
	}
}

func (b *fsBroker) determineManager(_ string) (string, error) {
	// this code checks whether cloud-init has finished booting the node, which
	// is indicative of most user-controlled actions being completed. it's not
	// perfect but it works under the basic assumptions.
	const cloudInitBootResultPath = "/run/cloud-init/result.json"
	if _, err := os.Stat(cloudInitBootResultPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return ManagerSystemd, nil
		}
		return "", err
	}
	return ManagerCNI, nil
}

func (b *fsBroker) ManagerFor(interfaceName string) (string, error) {
	// we check whether there is a manager already cached for this interface,
	// because we dont want to reconfigure interfaces from a previous boot for
	// the same EC2 instance.
	if manager, err := b.cache.Read(interfaceName); err == nil {
		return manager, nil
	}

	manager, err := b.determineManager(interfaceName)
	if err != nil {
		return "", err
	}

	if err := b.cache.Write(interfaceName, manager); err != nil {
		zap.L().Warn("failed writing manager back to cache", zap.Error(err), zap.String("interface", interfaceName), zap.String("manager", manager))
	}
	return manager, nil
}
