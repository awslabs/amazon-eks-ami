package udev

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/aws/smithy-go"
	"github.com/stretchr/testify/assert"
)

func Test_fsBroker_ManagerFor_retriesUntilOwnershipVisible(t *testing.T) {
	resolver := &fakeResolver{decision: ownershipPending}
	b := newTestBroker(t, true, true, staticResolver(resolver))
	var delays []time.Duration
	b.waitRetry = func(ctx context.Context, delay time.Duration) error {
		keys, err := b.cache.Keys()
		assert.NoError(t, err)
		assert.Empty(t, keys)
		delays = append(delays, delay)
		if len(delays) == 7 {
			resolver.decision = ownershipSystemd
		}
		return nil
	}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerSystemd, manager)
	assert.Equal(t, 8, resolver.calls)
	for i, ceiling := range []time.Duration{5, 10, 20, 40, 60, 60, 60} {
		assert.GreaterOrEqual(t, delays[i], ceiling*time.Second*4/5)
		assert.LessOrEqual(t, delays[i], ceiling*time.Second)
	}
}

func Test_fsBroker_ManagerFor_recoversFromLookupFailures(t *testing.T) {
	for _, code := range []string{"UnauthorizedOperation", "AuthFailure", "RequestLimitExceeded", "InternalError"} {
		t.Run(code, func(t *testing.T) {
			resolver := &fakeResolver{err: &smithy.GenericAPIError{Code: code}}
			b := newTestBroker(t, true, true, staticResolver(resolver))
			b.waitRetry = func(context.Context, time.Duration) error {
				resolver.err, resolver.decision = nil, ownershipSystemd
				return nil
			}
			manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
			assert.NoError(t, err)
			assert.Equal(t, ManagerSystemd, manager)
			assert.Equal(t, 2, resolver.calls)
		})
	}
}

func Test_fsBroker_ManagerFor_rechecksEligibility(t *testing.T) {
	for _, change := range []string{"link up", "feature disabled", "link removed"} {
		t.Run(change, func(t *testing.T) {
			resolver := &fakeResolver{decision: ownershipPending}
			b := newTestBroker(t, true, true, staticResolver(resolver))
			removedErr := errors.New("interface no longer exists")
			waits := 0
			b.waitRetry = func(context.Context, time.Duration) error {
				waits++
				switch change {
				case "link up":
					b.linkIsUp = func(string) (bool, error) { return true, nil }
				case "feature disabled":
					assert.NoError(t, os.Remove(b.noManageMarkerPath))
				case "link removed":
					b.linkIsUp = func(string) (bool, error) { return false, removedErr }
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
	t.Run("during backoff", func(t *testing.T) {
		resolver := &fakeResolver{decision: ownershipPending}
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
	})
	t.Run("during lookup", func(t *testing.T) {
		b := newTestBroker(t, true, true, staticResolver(blockingResolver{}))
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
		defer cancel()
		_, err := b.ManagerFor(ctx, "ens6", "mac")
		assert.ErrorIs(t, err, context.DeadlineExceeded)
	})
}

func Test_fsBroker_ManagerFor_lookupBudgetResets(t *testing.T) {
	builds := 0
	b := newTestBroker(t, true, true, func(ctx context.Context) (cniOptOutResolver, error) {
		builds++
		if builds == 1 {
			<-ctx.Done()
			return nil, ctx.Err()
		}
		assert.NoError(t, ctx.Err())
		return &fakeResolver{decision: ownershipSystemd}, nil
	})
	b.lookupTimeout = 10 * time.Millisecond
	b.waitRetry = func(context.Context, time.Duration) error { return nil }
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerSystemd, manager)
	assert.Equal(t, 2, builds)
}

func Test_fsBroker_ManagerFor_featureOffDoesNotWait(t *testing.T) {
	b := newTestBroker(t, true, false, unbuildableResolver)
	b.waitRetry = func(context.Context, time.Duration) error {
		t.Fatal("disabled feature must not enter ownership polling")
		return nil
	}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerCNI, manager)
}
