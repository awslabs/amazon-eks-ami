package udev

import (
	"context"
	"errors"
	"fmt"
	"net"
	"path/filepath"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkInterfaceBroker interface {
	ManagerFor(ctx context.Context, interfaceName, mac string) (string, error)
}

const NetworkManagerCacheDir = "/etc/eks/nodeadm/udev-net-manager"

const (
	// covers region/credential discovery and the describe call, including the
	// SDK's own retries.
	ownershipLookupTimeout = 10 * time.Second

	initialOwnershipRetryDelay = 5 * time.Second
	maxOwnershipRetryDelay     = time.Minute
)

var errOwnershipPending = errors.New("ENI ownership pending")

type fsBroker struct {
	cache              util.FSCache
	markerPath         string
	noManageMarkerPath string
	newResolver        func(ctx context.Context) (cniOptOutResolver, error)
	linkUp             func(interfaceName string) (bool, error)
	waitRetry          func(context.Context, time.Duration) error
}

func NewFSBroker(instanceID string) *fsBroker {
	return &fsBroker{
		cache:              util.NewFSCache(filepath.Join(NetworkManagerCacheDir, instanceID)),
		markerPath:         system.MarkerPath(),
		noManageMarkerPath: system.OSManagedNoManageENIsMarkerPath(),
		newResolver: func(ctx context.Context) (cniOptOutResolver, error) {
			return newEC2TagResolver(ctx, instanceID)
		},
		linkUp:    isLinkUp,
		waitRetry: waitForOwnershipRetry,
	}
}

func isLinkUp(interfaceName string) (bool, error) {
	link, err := net.InterfaceByName(interfaceName)
	if err != nil {
		return false, err
	}
	return link.Flags&net.FlagUp != 0, nil
}

func (b *fsBroker) determineManager(ctx context.Context, interfaceName, mac string) (string, error) {
	// This path is created when the second phase of nodeadm runs.
	// For users who incorrectly call nodeadm init in user data, this ensures
	// that systemd won't accidentally try to manage interfaces added by the
	// VPC CNI.
	markerExists, err := util.IsFilePathExists(b.markerPath)
	if err != nil {
		return "", err
	}
	if !markerExists {
		return ManagerSystemd, nil
	}

	noManageEnabled, err := util.IsFilePathExists(b.noManageMarkerPath)
	if err != nil {
		return "", err
	}
	if !noManageEnabled {
		return ManagerCNI, nil
	}

	up, err := b.linkUp(interfaceName)
	if err != nil {
		return "", err
	}
	if up {
		zap.L().Info("link already up, leaving it to its current manager", zap.String("interface", interfaceName))
		return ManagerCNI, nil
	}

	ctx, cancel := context.WithTimeout(ctx, ownershipLookupTimeout)
	defer cancel()

	resolver, err := b.newResolver(ctx)
	if err != nil {
		return "", fmt.Errorf("%w: %w", errOwnershipPending, err)
	}
	return resolver.Resolve(ctx, mac)
}

func (b *fsBroker) managerForAttempt(ctx context.Context, interfaceName, mac string) (string, error) {
	// we check whether there is a manager already cached for this interface,
	// because we dont want to reconfigure interfaces from a previous boot for
	// the same EC2 instance.
	if value, err := b.cache.Read(interfaceName); err == nil {
		if entry, err := decodeManagerCacheEntry(value); err == nil && entry.MAC == mac {
			return entry.Manager, nil
		}
	}

	manager, err := b.determineManager(ctx, interfaceName, mac)
	if err != nil {
		return "", err
	}

	if err := writeManagerCacheEntry(b.cache, interfaceName, mac, manager); err != nil {
		zap.L().Warn("failed writing manager back to cache", zap.Error(err), zap.String("interface", interfaceName), zap.String("manager", manager))
	}
	return manager, nil
}

func (b *fsBroker) ManagerFor(ctx context.Context, interfaceName, mac string) (string, error) {
	delay := initialOwnershipRetryDelay
	for {
		manager, err := b.managerForAttempt(ctx, interfaceName, mac)
		if err == nil {
			return manager, nil
		}
		// only EC2/credential failures and incomplete visibility poll here,
		// filesystem and link errors follow the systemd restart policy.
		if !errors.Is(err, errOwnershipPending) {
			return "", err
		}
		zap.L().Warn("waiting to resolve interface ownership", zap.String("interface", interfaceName), zap.String("mac", mac), zap.Duration("retryIn", delay), zap.Error(err))
		if err := b.waitRetry(ctx, delay); err != nil {
			return "", err
		}
		delay = min(2*delay, maxOwnershipRetryDelay)
	}
}

func waitForOwnershipRetry(ctx context.Context, delay time.Duration) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(delay):
		return nil
	}
}
