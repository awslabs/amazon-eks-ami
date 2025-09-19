package udev

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkInterfaceBroker interface {
	ManagerFor(interfaceName string) (string, error)
}

type fsBroker struct {
	cacheDir string
}

func NewFSBroker() *fsBroker {
	return &fsBroker{
		cacheDir: "/etc/eks/nodeadm/udev-net-manager",
	}
}

func (b *fsBroker) cachePath(instanceID, interfaceName string) string {
	return filepath.Join(b.cacheDir, instanceID, interfaceName)
}

func (b *fsBroker) readManagerCache(instanceID, interfaceName string) (string, error) {
	interfaceManagerBytes, err := os.ReadFile(b.cachePath(instanceID, interfaceName))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(interfaceManagerBytes)), nil
}

func (b *fsBroker) writeManagerCache(manager, instanceID, interfaceName string) error {
	return util.WriteFileWithDir(b.cachePath(instanceID, interfaceName), []byte(manager), 0644)
}

func (b *fsBroker) determineManager(_ string) (string, error) {
	// this code checks whether cloud-init has finished booting the node, which
	// is indicative of most user-controlled actions being completed. it's not
	// perfect but it works under the basic assumptions.
	const cloudInitBootResultPath = "/run/cloud-init/result.json"
	if _, err := os.Stat(cloudInitBootResultPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return managerSystemd, nil
		}
		return "", err
	}
	return managerCNI, nil
}

func (b *fsBroker) ManagerFor(interfaceName string) (string, error) {
	// we check whether there is a manager already cached for this interface,
	// because we dont want to reconfigure interfaces from a previous boot for
	// the same EC2 instance.
	identity, err := imds.DefaultClient().GetInstanceIdentityDocument(context.Background())
	if err != nil {
		return "", fmt.Errorf("failed to get instance ID from identity: %w", err)
	}

	if manager, err := b.readManagerCache(identity.InstanceID, interfaceName); err == nil {
		return manager, nil
	}

	manager, err := b.determineManager(interfaceName)
	if err != nil {
		return "", err
	}

	if err := b.writeManagerCache(manager, identity.InstanceID, interfaceName); err != nil {
		zap.L().Warn("failed writing manager back to cache", zap.Error(err), zap.String("interface", interfaceName), zap.String("manager", manager))
	}
	return manager, nil
}
