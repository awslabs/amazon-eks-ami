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
	decision ownershipDecision
	err      error
	calls    int
}

func (f *fakeResolver) Resolve(ctx context.Context, mac string) (ownershipDecision, error) {
	f.calls++
	return f.decision, f.err
}

// blockingResolver models a slow or unreachable EC2/IMDS endpoint.
type blockingResolver struct{}

func (blockingResolver) Resolve(ctx context.Context, mac string) (ownershipDecision, error) {
	<-ctx.Done()
	return ownershipPending, ctx.Err()
}

type resolverBuilder func(ctx context.Context) (cniOptOutResolver, error)

func staticResolver(r cniOptOutResolver) resolverBuilder {
	return func(context.Context) (cniOptOutResolver, error) { return r, nil }
}

func unbuildableResolver(context.Context) (cniOptOutResolver, error) {
	return nil, errors.New("resolver must not be built in this case")
}

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
		lookupTimeout:      defaultOptOutLookupTimeout,
		linkIsUp:           func(string) (bool, error) { return false, nil },
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
			resolver:     &fakeResolver{decision: ownershipSystemd},
			want:         ManagerSystemd,
			wantCalls:    1,
		},
		{
			name:         "feature on and ENI managed by CNI resolves to cni",
			markerExists: true,
			flagExists:   true,
			resolver:     &fakeResolver{decision: ownershipCNI},
			want:         ManagerCNI,
			wantCalls:    1,
		},
		{
			name:         "feature on but resolver errors propagates (so the unit retries)",
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

func Test_fsBroker_determineManager_lookupTimeout(t *testing.T) {
	b := newTestBroker(t, true, true, staticResolver(blockingResolver{}))
	b.lookupTimeout = 20 * time.Millisecond

	start := time.Now()
	got, err := b.determineManager(context.TODO(), "ens6", "mac")
	elapsed := time.Since(start)

	// a hung lookup errors promptly (so systemd retries the unit) rather than
	// caching a fallback decision.
	assert.Error(t, err)
	assert.Empty(t, got)
	assert.Less(t, elapsed, time.Second)
}

func Test_fsBroker_ManagerFor_prefersCache(t *testing.T) {
	// with the run-phase marker absent a recompute would yield ManagerSystemd, so
	// reading back ManagerCNI proves the cached value was used.
	b := newTestBroker(t, false, false, unbuildableResolver)
	if err := b.cache.Write("ens6", ManagerCNI); err != nil {
		t.Fatalf("failed to seed cache: %v", err)
	}

	got, err := b.ManagerFor(context.TODO(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerCNI, got)
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
			resolver:  &fakeResolver{decision: ownershipSystemd},
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
