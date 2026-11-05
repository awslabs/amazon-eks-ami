package networkmanager

import (
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
	assert.NoError(t, cache.Write("ens9", "garbage"))
	macs := map[string]string{"ens5": "primary", "ens6": "new", "ens8": "cni", "ens9": "garbage"}
	names, err := ManagedInterfaces(cache, func(name string) (string, error) {
		if mac, ok := macs[name]; ok {
			return mac, nil
		}
		return "", fs.ErrNotExist
	})
	assert.NoError(t, err)
	assert.Equal(t, []string{"ens5"}, names)
}
