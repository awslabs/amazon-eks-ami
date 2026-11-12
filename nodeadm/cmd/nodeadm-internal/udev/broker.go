package udev

import (
	"context"
	"net"
	"path/filepath"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkInterfaceBroker interface {
	ManagerFor(ctx context.Context, interfaceName, mac string) (string, error)
}

// bounds the resolver, including the IMDS and EC2 retries.
const ownershipLookupTimeout = 2 * time.Minute

type fsBroker struct {
	cache             util.FSCache
	markerPath        string
	eniTagsMarkerPath string
	newResolver       func(ctx context.Context) (ownershipResolver, error)
	linkUp            func(interfaceName string) (bool, error)
}

func NewFSBroker(instanceID string) *fsBroker {
	return &fsBroker{
		cache:             util.NewFSCache(filepath.Join(networkmanager.CacheDir, instanceID)),
		markerPath:        system.MarkerPath(),
		eniTagsMarkerPath: system.ENITagsMarkerPath(),
		newResolver: func(ctx context.Context) (ownershipResolver, error) {
			return newEC2TagResolver(ctx)
		},
		linkUp: isLinkUp,
	}
}

// Created by kubelet.service ExecStartPre. Keep in sync with
// templates/*/runtime/rootfs/etc/systemd/system/kubelet.service.
const kubeletStartedMarkerPath = "/run/eks/kubelet/started"

// initialized reports whether the second phase of nodeadm ran or
// kubelet.service started kubelet. For users who incorrectly call nodeadm init
// or who start kubelet from user data, this ensures that systemd won't
// accidentally try to manage interfaces added by the VPC CNI.
func (b *fsBroker) initialized() (bool, error) {
	for _, marker := range []string{b.markerPath, kubeletStartedMarkerPath} {
		exists, err := util.IsFilePathExists(marker)
		if err != nil || exists {
			return exists, err
		}
	}
	return false, nil
}

func isLinkUp(interfaceName string) (bool, error) {
	link, err := net.InterfaceByName(interfaceName)
	if err != nil {
		return false, err
	}
	return link.Flags&net.FlagUp != 0, nil
}

func (b *fsBroker) determineManager(ctx context.Context, interfaceName, mac string) (string, error) {
	initialized, err := b.initialized()
	if err != nil {
		return "", err
	}
	if !initialized {
		return networkmanager.ManagerSystemd, nil
	}

	eniTagsEnabled, err := util.IsFilePathExists(b.eniTagsMarkerPath)
	if err != nil {
		return "", err
	}
	if !eniTagsEnabled {
		return networkmanager.ManagerCNI, nil
	}

	up, err := b.linkUp(interfaceName)
	if err != nil {
		return "", err
	}
	if up {
		zap.L().Info("link already up, leaving it to its current manager", zap.String("interface", interfaceName))
		return networkmanager.ManagerCNI, nil
	}

	ctx, cancel := context.WithTimeout(ctx, ownershipLookupTimeout)
	defer cancel()

	resolver, err := b.newResolver(ctx)
	if err != nil {
		return "", err
	}
	return resolver.Resolve(ctx, mac)
}

func (b *fsBroker) ManagerFor(ctx context.Context, interfaceName, mac string) (string, error) {
	// we check whether there is a manager already cached for this interface,
	// because we dont want to reconfigure interfaces from a previous boot for
	// the same EC2 instance.
	if value, err := b.cache.Read(interfaceName); err == nil {
		if entry, err := networkmanager.DecodeCacheEntry(value); err == nil && entry.MAC == mac {
			return entry.Manager, nil
		}
	}

	manager, err := b.determineManager(ctx, interfaceName, mac)
	if err != nil {
		return "", err
	}

	if err := networkmanager.WriteCacheEntry(b.cache, interfaceName, mac, manager); err != nil {
		zap.L().Warn("failed writing manager back to cache", zap.Error(err), zap.String("interface", interfaceName), zap.String("manager", manager))
	}
	return manager, nil
}
