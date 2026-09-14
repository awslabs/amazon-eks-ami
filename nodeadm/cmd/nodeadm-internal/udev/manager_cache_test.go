package udev

import (
	"context"
	"io/fs"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_fsBroker_replacementENI(t *testing.T) {
	for _, priorManager := range []string{ManagerCNI, ManagerSystemd} {
		t.Run(priorManager, func(t *testing.T) {
			resolver := &fakeResolver{manager: ManagerSystemd}
			want := ManagerSystemd
			if priorManager == ManagerSystemd {
				resolver.manager, want = ManagerCNI, ManagerCNI
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

func Test_cachedManagedInterfaces(t *testing.T) {
	b := newTestBroker(t, false, false, unbuildableResolver)
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens5", "primary", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens6", "old", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens7", "gone", ManagerSystemd))
	assert.NoError(t, writeManagerCacheEntry(b.cache, "ens8", "cni", ManagerCNI))
	assert.NoError(t, b.cache.Write("ens9", "garbage"))
	macs := map[string]string{"ens5": "primary", "ens6": "new", "ens8": "cni", "ens9": "garbage"}
	names, err := cachedManagedInterfaces(b.cache, func(name string) (string, error) {
		if mac, ok := macs[name]; ok {
			return mac, nil
		}
		return "", fs.ErrNotExist
	})
	assert.NoError(t, err)
	assert.Equal(t, []string{"ens5"}, names)
}
