package udev

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func Test_fsBroker_replacementENI(t *testing.T) {
	for _, priorManager := range []string{ManagerCNI, ManagerSystemd} {
		t.Run(priorManager, func(t *testing.T) {
			resolver := &fakeResolver{decision: ownershipSystemd}
			want := ManagerSystemd
			if priorManager == ManagerSystemd {
				resolver.decision, want = ownershipCNI, ManagerCNI
			}
			b := newTestBroker(t, true, true, staticResolver(resolver))
			assert.NoError(t, writeManagerCacheEntry(b.cache, "ens6", "old-mac", priorManager))
			manager, err := b.ManagerFor(context.Background(), "ens6", "new-mac")
			assert.NoError(t, err)
			assert.Equal(t, want, manager)
			assert.Equal(t, 1, resolver.calls)
			value, err := b.cache.Read("ens6")
			assert.NoError(t, err)
			entry, err := decodeManagerCacheEntry(value)
			assert.NoError(t, err)
			assert.Equal(t, managerCacheEntry{MAC: "new-mac", Manager: want}, entry)
		})
	}
}

func Test_fsBroker_sameENIAcrossBoot(t *testing.T) {
	for _, manager := range []string{ManagerCNI, ManagerSystemd} {
		b := newTestBroker(t, false, false, unbuildableResolver)
		assert.NoError(t, writeManagerCacheEntry(b.cache, "ens6", "mac", manager))
		got, err := b.ManagerFor(context.Background(), "ens6", "mac")
		assert.NoError(t, err)
		assert.Equal(t, manager, got)
	}
}

func Test_fsBroker_legacyCacheMigration(t *testing.T) {
	for _, manager := range []string{ManagerCNI, ManagerSystemd} {
		b := newTestBroker(t, false, false, unbuildableResolver)
		assert.NoError(t, b.cache.Write("ens6", manager))
		got, err := b.ManagerFor(context.Background(), "ens6", "mac")
		assert.NoError(t, err)
		assert.Equal(t, manager, got)
		value, err := b.cache.Read("ens6")
		assert.NoError(t, err)
		entry, err := decodeManagerCacheEntry(value)
		assert.NoError(t, err)
		assert.Equal(t, managerCacheEntry{MAC: "mac", Manager: manager}, entry)
	}
}

func Test_fsBroker_corruptCacheDoesNotAdopt(t *testing.T) {
	for _, value := range []string{"", "unknown", `{"mac":"mac","manager":"unknown"}`, `{"manager":"io.systemd.Network"}`} {
		b := newTestBroker(t, false, false, unbuildableResolver)
		assert.NoError(t, b.cache.Write("ens6", value))
		manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
		assert.Error(t, err)
		assert.Empty(t, manager)
	}
}

func Test_fsBroker_identityChangesWhilePending(t *testing.T) {
	resolver := &fakeResolver{decision: ownershipPending}
	b := newTestBroker(t, true, true, staticResolver(resolver))
	replaced := errors.New("interface replaced")
	b.waitRetry = func(context.Context, time.Duration) error {
		b.checkIdentity = func(string, string) error { return replaced }
		resolver.decision = ownershipSystemd
		return nil
	}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.ErrorIs(t, err, replaced)
	assert.Empty(t, manager)
	assert.Equal(t, 1, resolver.calls)
	keys, err := b.cache.Keys()
	assert.NoError(t, err)
	assert.Empty(t, keys)
}

func Test_cachedManagedInterfaces(t *testing.T) {
	b := newTestBroker(t, false, false, unbuildableResolver)
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens5", "primary", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens6", "old", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens7", "gone", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens8", "cni", ManagerCNI))
	macs := map[string]string{"ens5": "primary", "ens6": "new", "ens8": "cni"}
	names, err := cachedManagedInterfaces(b.cache, func(name string) (string, error) {
		if mac, ok := macs[name]; ok {
			return mac, nil
		}
		return "", fs.ErrNotExist
	})
	assert.NoError(t, err)
	assert.Equal(t, []string{"ens5"}, names)
}

func Test_removeStaleNetworkConfig(t *testing.T) {
	for _, mac := range []string{"same", "replaced"} {
		t.Run(mac, func(t *testing.T) {
			configPath := filepath.Join(t.TempDir(), "70-eks-ens6.network")
			assert.NoError(t, os.WriteFile(configPath, []byte("[Match]\nPermanentMACAddress=same\n"), 0644))
			assert.NoError(t, removeStaleNetworkConfig(configPath, mac))
			_, err := os.Stat(configPath)
			if mac == "same" {
				assert.NoError(t, err)
			} else {
				assert.ErrorIs(t, err, fs.ErrNotExist)
			}
			assert.NoError(t, removeStaleNetworkConfig(configPath, mac))
		})
	}
}
