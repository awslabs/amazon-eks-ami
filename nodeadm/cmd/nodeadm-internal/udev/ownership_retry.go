package udev

import (
	"context"
	"errors"
	"math/rand/v2"
	"time"

	"github.com/aws/smithy-go"
	"go.uber.org/zap"
)

const (
	initialOwnershipRetryDelay = 5 * time.Second
	maxOwnershipRetryDelay     = time.Minute
)

// Only EC2/credential failures and incomplete ownership visibility retry here.
// Filesystem and link errors still follow the existing systemd restart policy.
type optOutLookupError struct{ error }

func (e *optOutLookupError) Unwrap() error { return e.error }

func (b *fsBroker) ManagerFor(ctx context.Context, interfaceName, mac string) (string, error) {
	delay := initialOwnershipRetryDelay
	lastReason := ""
	for {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		manager, err := b.managerForAttempt(ctx, interfaceName, mac)
		if err == nil {
			return manager, nil
		}
		var lookupErr *optOutLookupError
		if !errors.Is(err, errOwnershipUnknown) && !errors.As(err, &lookupErr) {
			return "", err
		}
		if ctx.Err() != nil {
			return "", ctx.Err()
		}

		// Log changes in the reason, not every poll during an extended outage.
		reason := ownershipRetryReason(err)
		if reason != lastReason {
			fields := []zap.Field{zap.String("interface", interfaceName), zap.String("mac", mac), zap.String("reason", reason)}
			if lookupErr != nil {
				zap.L().Warn("waiting to resolve interface ownership", append(fields, zap.Error(err))...)
			} else {
				zap.L().Info("waiting to resolve interface ownership", fields...)
			}
			lastReason = reason
		}

		// Jitter stays between 80% and 100% of the exponential delay. The cap
		// therefore remains one minute, even when multiple links are pending.
		if err := b.waitRetry(ctx, jitterOwnershipDelay(delay)); err != nil {
			return "", err
		}
		delay = min(2*delay, maxOwnershipRetryDelay)
	}
}

func ownershipRetryReason(err error) string {
	if errors.Is(err, errOwnershipUnknown) {
		return "ENI or ownership tag not yet visible"
	}
	var apiErr smithy.APIError
	if errors.As(err, &apiErr) {
		return apiErr.ErrorCode()
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "EC2 lookup deadline exceeded"
	}
	return "EC2 or credential lookup failed"
}

func jitterOwnershipDelay(delay time.Duration) time.Duration {
	jitter := delay / 5
	return delay - jitter + time.Duration(rand.Int64N(int64(jitter)+1))
}

func waitForOwnershipRetry(ctx context.Context, delay time.Duration) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(delay):
		return nil
	}
}
