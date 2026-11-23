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

// linkStates answers successive link checks with states, repeating the last one.
func linkStates(states ...bool) func(string) (bool, error) {
	calls := 0
	return func(string) (bool, error) {
		up := states[min(calls, len(states)-1)]
		calls++
		return up, nil
	}
}

// newTestBroker roots a broker's cache at a temp dir.
func newTestBroker(t *testing.T, initialized, eniTags bool, newResolver resolverBuilder) *fsBroker {
	t.Helper()
	return &fsBroker{
		cache:       util.NewFSCache(filepath.Join(t.TempDir(), "cache")),
		state:       nodeState{initialized: initialized, eniTags: eniTags},
		newResolver: newResolver,
		linkUp:      linkDown,
	}
}

func Test_readNodeState(t *testing.T) {
	for _, tc := range []struct {
		name    string
		markers []string
		want    nodeState
	}{
		{name: "no markers"},
		{name: "run phase", markers: []string{"init"}, want: nodeState{initialized: true}},
		{name: "kubelet started", markers: []string{"kubelet"}, want: nodeState{initialized: true}},
		{name: "eni tags only", markers: []string{"eni-tags"}, want: nodeState{eniTags: true}},
		{name: "all", markers: []string{"init", "kubelet", "eni-tags"}, want: nodeState{initialized: true, eniTags: true}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			for _, m := range tc.markers {
				assert.NoError(t, util.WriteFileWithDir(filepath.Join(dir, m), nil, 0644))
			}
			got, err := readNodeState(filepath.Join(dir, "init"), filepath.Join(dir, "kubelet"), filepath.Join(dir, "eni-tags"))
			assert.NoError(t, err)
			assert.Equal(t, tc.want, got)
		})
	}
}

func Test_fsBroker_determineManager(t *testing.T) {
	tests := []struct {
		name        string
		initialized bool
		eniTags     bool
		link        []bool
		resolver    *fakeResolver
		want        string
		wantBuilt   bool
		wantCalls   int
	}{
		{
			name:        "no marker resolves to systemd (early boot / primary)",
			initialized: false,
			want:        networkmanager.ManagerSystemd,
		},
		{
			name:        "marker present but feature off resolves to cni without EC2 call",
			initialized: true,
			eniTags:     false,
			want:        networkmanager.ManagerCNI,
		},
		{
			name:        "feature on and system managed ENI resolves to systemd",
			initialized: true,
			eniTags:     true,
			resolver:    &fakeResolver{manager: networkmanager.ManagerSystemd},
			want:        networkmanager.ManagerSystemd,
			wantBuilt:   true,
			wantCalls:   1,
		},
		{
			name:        "feature on and ENI managed by CNI resolves to cni",
			initialized: true,
			eniTags:     true,
			resolver:    &fakeResolver{manager: networkmanager.ManagerCNI},
			want:        networkmanager.ManagerCNI,
			wantBuilt:   true,
			wantCalls:   1,
		},
		{
			name:        "link already up resolves to cni without EC2 call",
			initialized: true,
			eniTags:     true,
			link:        []bool{true},
			want:        networkmanager.ManagerCNI,
		},
		{
			name:        "resolver error falls back to cni",
			initialized: true,
			eniTags:     true,
			resolver:    &fakeResolver{err: errors.New("boom")},
			want:        networkmanager.ManagerCNI,
			wantBuilt:   true,
			wantCalls:   1,
		},
		{
			name:        "link up after resolving to systemd resolves to cni",
			initialized: true,
			eniTags:     true,
			link:        []bool{false, true},
			resolver:    &fakeResolver{manager: networkmanager.ManagerSystemd},
			want:        networkmanager.ManagerCNI,
			wantBuilt:   true,
			wantCalls:   1,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := tc.resolver
			resolverBuilt := false
			b := newTestBroker(t, tc.initialized, tc.eniTags, func(ctx context.Context) (ownershipResolver, error) {
				resolverBuilt = true
				if res == nil {
					return unbuildableResolver(ctx)
				}
				return res, nil
			})
			if tc.link != nil {
				b.linkUp = linkStates(tc.link...)
			}

			got, err := b.determineManager(context.TODO(), "ens6", "0a:1b:2c:3d:4e:5f")
			assert.NoError(t, err)
			assert.Equal(t, tc.want, got)
			// guards the short-circuits that guarantee zero EC2 calls.
			assert.Equal(t, tc.wantBuilt, resolverBuilt)
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
		// resolver invocations across two ManagerFor calls; 1 means the second
		// call was served from cache.
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
			name:      "resolver error falls back to cni and is cached",
			resolver:  &fakeResolver{err: errors.New("boom")},
			want:      networkmanager.ManagerCNI,
			wantCalls: 1,
			wantKeys:  []string{"ens6"},
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			b := newTestBroker(t, true, true, staticResolver(tc.resolver))

			for i := 0; i < 2; i++ {
				got, err := b.ManagerFor(context.TODO(), "ens6", "mac")
				assert.NoError(t, err)
				assert.Equal(t, tc.want, got)
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
			entry, found, err := networkmanager.ReadCacheEntry(b.cache, "ens6")
			assert.NoError(t, err)
			assert.True(t, found)
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

func Test_fsBroker_corruptCacheEntry(t *testing.T) {
	b := newTestBroker(t, true, true, unbuildableResolver)
	assert.NoError(t, b.cache.Write("ens6", "garbage"))
	got, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.Error(t, err)
	assert.Empty(t, got)
	value, err := b.cache.Read("ens6")
	assert.NoError(t, err)
	assert.Equal(t, "garbage", value)
}
