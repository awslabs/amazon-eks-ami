package udev

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
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

// defaultOptOutLookupTimeout bounds client build (region/credential discovery
// via IMDS) plus describe, capping the SDK's retry/backoff. Other IMDS calls
// in addAction retain their existing retry behavior.
const defaultOptOutLookupTimeout = 10 * time.Second

var errOwnershipUnknown = errors.New("ENI ownership tags not yet visible")

type fsBroker struct {
	cache              util.FSCache
	markerPath         string
	noManageMarkerPath string
	// newResolver is built lazily, so the EC2 client and its IAM requirement are
	// never exercised unless the feature is enabled.
	newResolver   func(ctx context.Context) (cniOptOutResolver, error)
	lookupTimeout time.Duration
	linkIsUp      func(string) (bool, error)
}

func NewFSBroker(instanceID string) *fsBroker {
	return &fsBroker{
		cache:              util.NewFSCache(filepath.Join(NetworkManagerCacheDir, instanceID)),
		markerPath:         system.MarkerPath(),
		noManageMarkerPath: system.OSManagedNoManageENIsMarkerPath(),
		newResolver: func(ctx context.Context) (cniOptOutResolver, error) {
			return newEC2TagResolver(ctx, instanceID)
		},
		lookupTimeout: defaultOptOutLookupTimeout,
		linkIsUp: func(name string) (bool, error) {
			link, err := net.InterfaceByName(name)
			if err != nil {
				return false, err
			}
			return link.Flags&net.FlagUp != 0, nil
		},
	}
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

	// feature off: default to CNI, no EC2 call.
	noManageEnabled, err := util.IsFilePathExists(b.noManageMarkerPath)
	if err != nil {
		return "", err
	}
	if !noManageEnabled {
		return ManagerCNI, nil
	}

	// An up link is a reason to leave management alone, not proof that CNI owns
	// it. ManagerCNI also represents delegation to an existing external manager.
	up, err := b.linkIsUp(interfaceName)
	if err != nil {
		return "", err
	}
	if up {
		zap.L().Info("deferring interface management", zap.String("interface", interfaceName), zap.String("manager", ManagerCNI), zap.String("reason", "link already up"))
		return ManagerCNI, nil
	}

	// Propagated, not defaulted to CNI: ManagerFor caches the result permanently,
	// and the unit retries on failure (Restart=on-failure).
	ctx, cancel := context.WithTimeout(ctx, b.lookupTimeout)
	defer cancel()

	resolver, err := b.newResolver(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to build CNI opt-out resolver for mac %s: %w", mac, err)
	}
	decision, err := resolver.Resolve(ctx, mac)
	if err != nil {
		return "", fmt.Errorf("failed to determine CNI opt-out status for mac %s: %w", mac, err)
	}
	switch decision {
	case ownershipSystemd:
		// CNI may have brought the link up during the EC2 request.
		up, err := b.linkIsUp(interfaceName)
		if err != nil {
			return "", err
		}
		if up {
			zap.L().Info("deferring interface management", zap.String("interface", interfaceName), zap.String("manager", ManagerCNI), zap.String("reason", "link brought up during EC2 lookup"))
			return ManagerCNI, nil
		}
		return ManagerSystemd, nil
	case ownershipCNI:
		return ManagerCNI, nil
	case ownershipPending:
		return "", fmt.Errorf("mac %s: %w", mac, errOwnershipUnknown)
	default:
		return "", fmt.Errorf("invalid ownership decision: %d", decision)
	}
}

func (b *fsBroker) ManagerFor(ctx context.Context, interfaceName, mac string) (string, error) {
	// we check whether there is a manager already cached for this interface,
	// because we dont want to reconfigure interfaces from a previous boot for
	// the same EC2 instance.
	manager, err := b.cache.Read(interfaceName)
	if err == nil {
		return manager, nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		// unlike a cold cache, this (e.g. a cache dir permissions problem) would
		// silently force a full re-resolution on every event.
		zap.L().Warn("failed reading manager from cache, re-resolving", zap.Error(err), zap.String("interface", interfaceName))
	}

	manager, err = b.determineManager(ctx, interfaceName, mac)
	if err != nil {
		return "", err
	}

	if err := b.cache.Write(interfaceName, manager); err != nil {
		zap.L().Warn("failed writing manager back to cache", zap.Error(err), zap.String("interface", interfaceName), zap.String("manager", manager))
	}
	return manager, nil
}
