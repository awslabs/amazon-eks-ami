package udev

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"

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

type resolverBuilder func(ctx context.Context) (cniOptOutResolver, error)

func staticResolver(r cniOptOutResolver) resolverBuilder {
	return func(context.Context) (cniOptOutResolver, error) { return r, nil }
}

func unbuildableResolver(context.Context) (cniOptOutResolver, error) {
	return nil, errors.New("resolver must not be built in this case")
}

func linkDown(string) (bool, error) { return false, nil }

// newTestBroker roots a broker at a temp dir, creating the run-phase and feature
// gate markers as requested.
func newTestBroker(t *testing.T, markerExists, flagExists bool, newResolver resolverBuilder) *fsBroker {
	t.Helper()
	dir := t.TempDir()
	b := &fsBroker{
		cache:              util.NewFSCache(filepath.Join(dir, "cache")),
		markerPath:         filepath.Join(dir, "init"),
		noManageMarkerPath: filepath.Join(dir, "no-manage"),
		newResolver:        newResolver,
		linkUp:             linkDown,
		waitRetry:          waitForOwnershipRetry,
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
	touch(b.noManageMarkerPath, flagExists)
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
			want:         ManagerSystemd,
		},
		{
			name:         "marker present but feature off resolves to cni without EC2 call",
			markerExists: true,
			flagExists:   false,
			want:         ManagerCNI,
		},
		{
			name:         "feature on and ENI opted out of CNI resolves to systemd",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{manager: ManagerSystemd},
			want:         ManagerSystemd,
			wantCalls:    1,
		},
		{
			name:         "feature on and ENI managed by CNI resolves to cni",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{manager: ManagerCNI},
			want:         ManagerCNI,
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
			b := newTestBroker(t, tc.markerExists, tc.flagExists, func(ctx context.Context) (cniOptOutResolver, error) {
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

func Test_fsBroker_managerForAttempt_caching(t *testing.T) {
	tests := []struct {
		name     string
		resolver *fakeResolver
		want     string
		wantErr  bool
		// resolver invocations across two managerForAttempt calls: 1 means the second
		// call was served from cache, 2 means the decision was re-resolved.
		wantCalls int
		wantKeys  []string
	}{
		{
			name:      "decision is cached and reused",
			resolver:  &fakeResolver{manager: ManagerSystemd},
			want:      ManagerSystemd,
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
				got, err := b.managerForAttempt(context.TODO(), "ens6", "mac")
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

func Test_fsBroker_ManagerFor_retriesUntilOwnershipVisible(t *testing.T) {
	resolver := &fakeResolver{err: errOwnershipPending}
	b := newTestBroker(t, true, true, staticResolver(resolver))
	var delays []time.Duration
	b.waitRetry = func(ctx context.Context, delay time.Duration) error {
		keys, err := b.cache.Keys()
		assert.NoError(t, err)
		assert.Empty(t, keys)
		delays = append(delays, delay)
		if len(delays) == 7 {
			resolver.manager, resolver.err = ManagerSystemd, nil
		}
		return nil
	}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerSystemd, manager)
	assert.Equal(t, 8, resolver.calls)
	assert.Equal(t, []time.Duration{5 * time.Second, 10 * time.Second, 20 * time.Second, 40 * time.Second, time.Minute, time.Minute, time.Minute}, delays)
}

func Test_fsBroker_ManagerFor_rechecksEligibility(t *testing.T) {
	for _, change := range []string{"link up", "link removed"} {
		t.Run(change, func(t *testing.T) {
			resolver := &fakeResolver{err: errOwnershipPending}
			b := newTestBroker(t, true, true, staticResolver(resolver))
			removedErr := errors.New("interface no longer exists")
			waits := 0
			b.waitRetry = func(context.Context, time.Duration) error {
				waits++
				switch change {
				case "link up":
					b.linkUp = func(string) (bool, error) { return true, nil }
				case "link removed":
					b.linkUp = func(string) (bool, error) { return false, removedErr }
				}
				return nil
			}
			manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
			if change == "link removed" {
				assert.ErrorIs(t, err, removedErr)
				assert.Empty(t, manager)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, ManagerCNI, manager)
			}
			assert.Equal(t, 1, waits)
			assert.Equal(t, 1, resolver.calls)
		})
	}
}

func Test_fsBroker_ManagerFor_cancellation(t *testing.T) {
	resolver := &fakeResolver{err: errOwnershipPending}
	b := newTestBroker(t, true, true, staticResolver(resolver))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	b.waitRetry = func(ctx context.Context, delay time.Duration) error {
		cancel()
		return waitForOwnershipRetry(ctx, delay)
	}
	_, err := b.ManagerFor(ctx, "ens6", "mac")
	assert.ErrorIs(t, err, context.Canceled)
	assert.Equal(t, 1, resolver.calls)
}
