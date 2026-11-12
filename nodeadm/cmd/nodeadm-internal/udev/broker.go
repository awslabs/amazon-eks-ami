package udev

import (
	"context"
	"net"
	"path/filepath"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkInterfaceBroker interface {
	ManagerFor(ctx context.Context, interfaceName, mac string) (string, error)
}

// bounds the resolver, including the IMDS and EC2 retries.
const ownershipLookupTimeout = 2 * time.Minute

type fsBroker struct {
	cache       util.FSCache
	state       nodeState
	newResolver func(ctx context.Context) (ownershipResolver, error)
	linkUp      func(interfaceName string) (bool, error)
}

func NewFSBroker(instanceID string, state nodeState) *fsBroker {
	return &fsBroker{
		cache: util.NewFSCache(filepath.Join(networkmanager.CacheDir, instanceID)),
		state: state,
		newResolver: func(ctx context.Context) (ownershipResolver, error) {
			return newEC2TagResolver(ctx)
		},
		linkUp: isLinkUp,
	}
}

// Created by kubelet.service ExecStartPre. Keep in sync with
// templates/*/runtime/rootfs/etc/systemd/system/kubelet.service.
const kubeletStartedMarkerPath = "/run/eks/kubelet/started"

// nodeState is the node as seen by the markers when the ENI was attached.
type nodeState struct {
	// the second phase of nodeadm ran or kubelet.service started kubelet. For
	// users who incorrectly call nodeadm init or who start kubelet from user
	// data, this ensures that systemd won't accidentally try to manage
	// interfaces added by the VPC CNI.
	initialized bool
	eniTags     bool
}

func readNodeState(runMarker, kubeletMarker, eniTagsMarker string) (nodeState, error) {
	var state nodeState
	for _, marker := range []string{runMarker, kubeletMarker} {
		exists, err := util.IsFilePathExists(marker)
		if err != nil {
			return nodeState{}, err
		}
		state.initialized = state.initialized || exists
	}
	eniTags, err := util.IsFilePathExists(eniTagsMarker)
	if err != nil {
		return nodeState{}, err
	}
	state.eniTags = eniTags
	return state, nil
}

func isLinkUp(interfaceName string) (bool, error) {
	link, err := net.InterfaceByName(interfaceName)
	if err != nil {
		return false, err
	}
	return link.Flags&net.FlagUp != 0, nil
}

func (b *fsBroker) determineManager(ctx context.Context, interfaceName, mac string) (string, error) {
	if !b.state.initialized {
		return networkmanager.ManagerSystemd, nil
	}
	if !b.state.eniTags {
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
	entry, found, err := networkmanager.ReadCacheEntry(b.cache, interfaceName)
	if err != nil {
		return "", err
	}
	if found && entry.MAC == mac {
		return entry.Manager, nil
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
