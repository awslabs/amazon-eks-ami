package networkmanager

import (
	"errors"
	"io/fs"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

func TestManagedInterfaces(t *testing.T) {
	cache := util.NewFSCache(t.TempDir())
	assert.NoError(t, WriteCacheEntry(cache, "ens5", "primary", ManagerSystemd))
	assert.NoError(t, WriteCacheEntry(cache, "ens6", "old", ManagerSystemd))
	assert.NoError(t, WriteCacheEntry(cache, "ens7", "gone", ManagerSystemd))
	assert.NoError(t, WriteCacheEntry(cache, "ens8", "cni", ManagerCNI))
	macs := map[string]string{"ens5": "primary", "ens6": "new", "ens8": "cni"}
	names, err := ManagedInterfaces(cache, func(name string) (string, error) {
		if mac, ok := macs[name]; ok {
			return mac, nil
		}
		return "", fs.ErrNotExist
	})
	assert.NoError(t, err)
	assert.Equal(t, []string{"ens5"}, names)
}

func TestManagedInterfaces_errors(t *testing.T) {
	macErr := errors.New("boom")
	for _, tc := range []struct {
		name  string
		write func(util.FSCache) error
		mac   func(string) (string, error)
	}{
		{
			name:  "undecodable entry",
			write: func(c util.FSCache) error { return c.Write("ens5", "garbage") },
			mac:   func(string) (string, error) { return "mac", nil },
		},
		{
			name:  "unreadable address",
			write: func(c util.FSCache) error { return WriteCacheEntry(c, "ens5", "mac", ManagerSystemd) },
			mac:   func(string) (string, error) { return "", macErr },
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cache := util.NewFSCache(t.TempDir())
			assert.NoError(t, tc.write(cache))
			names, err := ManagedInterfaces(cache, tc.mac)
			assert.Error(t, err)
			assert.Nil(t, names)
		})
	}
}

func TestReadCacheEntry(t *testing.T) {
	cache := util.NewFSCache(t.TempDir())
	_, found, err := ReadCacheEntry(cache, "ens5")
	assert.NoError(t, err)
	assert.False(t, found)

	assert.NoError(t, WriteCacheEntry(cache, "ens5", "mac", ManagerSystemd))
	entry, found, err := ReadCacheEntry(cache, "ens5")
	assert.NoError(t, err)
	assert.True(t, found)
	assert.Equal(t, CacheEntry{MAC: "mac", Manager: ManagerSystemd}, entry)

	assert.NoError(t, cache.Write("ens5", "systemd"))
	_, _, err = ReadCacheEntry(cache, "ens5")
	assert.Error(t, err)
}
