package udev

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

type fakeResolver struct {
	manager string
	err     error
	calls   int
}

func (f *fakeResolver) Resolve(ctx context.Context, mac string) (string, error) {
	f.calls++
	return f.manager, f.err
}

type resolverBuilder func(ctx context.Context) (ownershipResolver, error)

func staticResolver(r ownershipResolver) resolverBuilder {
	return func(context.Context) (ownershipResolver, error) { return r, nil }
}

func unbuildableResolver(context.Context) (ownershipResolver, error) {
	return nil, errors.New("resolver must not be built in this case")
}

func linkDown(string) (bool, error) { return false, nil }

// newTestBroker roots a broker at a temp dir, creating the run-phase and feature
// gate markers as requested.
func newTestBroker(t *testing.T, markerExists, flagExists bool, newResolver resolverBuilder) *fsBroker {
	t.Helper()
	dir := t.TempDir()
	b := &fsBroker{
		cache:             util.NewFSCache(filepath.Join(dir, "cache")),
		markerPath:        filepath.Join(dir, "init"),
		eniTagsMarkerPath: filepath.Join(dir, "eni-tags"),
		newResolver:       newResolver,
		linkUp:            linkDown,
	}
	touch := func(path string, create bool) {
		if !create {
			return
		}
		if err := util.WriteFileWithDir(path, nil, 0644); err != nil {
			t.Fatalf("failed to create %s: %v", path, err)
		}
	}
	touch(b.markerPath, markerExists)
	touch(b.eniTagsMarkerPath, flagExists)
	return b
}

func Test_fsBroker_determineManager(t *testing.T) {
	tests := []struct {
		name         string
		markerExists bool
		flagExists   bool
		resolver     *fakeResolver
		want         string
		wantErr      bool
		wantCalls    int
	}{
		{
			name:         "no marker resolves to systemd (early boot / primary)",
			markerExists: false,
			want:         networkmanager.ManagerSystemd,
		},
		{
			name:         "marker present but feature off resolves to cni without EC2 call",
			markerExists: true,
			flagExists:   false,
			want:         networkmanager.ManagerCNI,
		},
		{
			name:         "feature on and system managed ENI resolves to systemd",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{manager: networkmanager.ManagerSystemd},
			want:         networkmanager.ManagerSystemd,
			wantCalls:    1,
		},
		{
			name:         "feature on and ENI managed by CNI resolves to cni",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{manager: networkmanager.ManagerCNI},
			want:         networkmanager.ManagerCNI,
			wantCalls:    1,
		},
		{
			name:         "feature on but resolver errors propagates",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{err: errors.New("boom")},
			wantErr:      true,
			wantCalls:    1,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := tc.resolver
			resolverBuilt := false
			b := newTestBroker(t, tc.markerExists, tc.flagExists, func(ctx context.Context) (ownershipResolver, error) {
				resolverBuilt = true
				if res == nil {
					return unbuildableResolver(ctx)
				}
				return res, nil
			})

			got, err := b.determineManager(context.TODO(), "ens6", "0a:1b:2c:3d:4e:5f")
			if tc.wantErr {
				assert.Error(t, err)
				assert.Empty(t, got)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tc.want, got)
			}
			// guards the feature-off short-circuit that guarantees zero EC2 calls.
			assert.Equal(t, tc.markerExists && tc.flagExists, resolverBuilt)
			if tc.resolver != nil {
				assert.Equal(t, tc.wantCalls, tc.resolver.calls)
			}
		})
	}
}

func Test_fsBroker_ManagerFor_caching(t *testing.T) {
	tests := []struct {
		name     string
		resolver *fakeResolver
		want     string
		wantErr  bool
		// resolver invocations across two ManagerFor calls: 1 means the second
		// call was served from cache, 2 means the decision was re-resolved.
		wantCalls int
		wantKeys  []string
	}{
		{
			name:      "decision is cached and reused",
			resolver:  &fakeResolver{manager: networkmanager.ManagerSystemd},
			want:      networkmanager.ManagerSystemd,
			wantCalls: 1,
			wantKeys:  []string{"ens6"},
		},
		{
			name:      "error is not cached and is re-resolved",
			resolver:  &fakeResolver{err: errors.New("boom")},
			wantErr:   true,
			wantCalls: 2,
			wantKeys:  nil,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			b := newTestBroker(t, true, true, staticResolver(tc.resolver))

			for i := 0; i < 2; i++ {
				got, err := b.ManagerFor(context.TODO(), "ens6", "mac")
				if tc.wantErr {
					assert.Error(t, err)
					assert.Empty(t, got)
				} else {
					assert.NoError(t, err)
					assert.Equal(t, tc.want, got)
				}
			}

			assert.Equal(t, tc.wantCalls, tc.resolver.calls)
			keys, err := b.cache.Keys()
			assert.NoError(t, err)
			assert.Equal(t, tc.wantKeys, keys)
		})
	}
}

func Test_fsBroker_replacementENI(t *testing.T) {
	for _, priorManager := range []string{networkmanager.ManagerCNI, networkmanager.ManagerSystemd} {
		t.Run(priorManager, func(t *testing.T) {
			resolver := &fakeResolver{manager: networkmanager.ManagerSystemd}
			want := networkmanager.ManagerSystemd
			if priorManager == networkmanager.ManagerSystemd {
				resolver.manager, want = networkmanager.ManagerCNI, networkmanager.ManagerCNI
			}
			b := newTestBroker(t, true, true, staticResolver(resolver))
			assert.NoError(t, networkmanager.WriteCacheEntry(b.cache, "ens6", "old-mac", priorManager))
			manager, err := b.ManagerFor(context.Background(), "ens6", "new-mac")
			assert.NoError(t, err)
			assert.Equal(t, want, manager)
			assert.Equal(t, 1, resolver.calls)
			value, err := b.cache.Read("ens6")
			assert.NoError(t, err)
			entry, err := networkmanager.DecodeCacheEntry(value)
			assert.NoError(t, err)
			assert.Equal(t, networkmanager.CacheEntry{MAC: "new-mac", Manager: want}, entry)
		})
	}
}

func Test_fsBroker_sameENIAcrossBoot(t *testing.T) {
	for _, manager := range []string{networkmanager.ManagerCNI, networkmanager.ManagerSystemd} {
		b := newTestBroker(t, false, false, unbuildableResolver)
		assert.NoError(t, networkmanager.WriteCacheEntry(b.cache, "ens6", "mac", manager))
		got, err := b.ManagerFor(context.Background(), "ens6", "mac")
		assert.NoError(t, err)
		assert.Equal(t, manager, got)
	}
}
