package util

import (
	"context"
	"time"
)

type Retrier struct {
	ConditionFn func(*Retrier) bool
	BackoffFn   func(*Retrier) time.Duration

	LastErr  error
	LastWait time.Duration
	LastIter int
}

func (r *Retrier) Retry(ctx context.Context, fn func() error) error {
	for r.LastIter = 0; r.ConditionFn(r); r.LastIter++ {
		if r.LastErr = fn(); r.LastErr == nil {
			return r.LastErr
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			time.Sleep(r.LastWait)
			r.LastWait = r.BackoffFn(r)
		}
	}
	return r.LastErr
}

type fnOpt func(*Retrier)

func NewRetrier(fnOpts ...fnOpt) *Retrier {
	retrier := Retrier{
		LastErr:  nil,
		LastIter: 0,
		LastWait: time.Second,
	}
	for _, fn := range append([]fnOpt{
		WithRetryCount(5),
		WithBackoffExponential(),
	}, fnOpts...) {
		fn(&retrier)
	}
	return &retrier
}

func WithRetryCount(maxAttempts int) fnOpt {
	return func(r *Retrier) {
		r.ConditionFn = func(r *Retrier) bool { return r.LastIter < maxAttempts }
	}
}

func WithRetryAlways() fnOpt {
	return func(r *Retrier) {
		r.ConditionFn = func(r *Retrier) bool { return true }
	}
}

func WithBackoffFixed(interval time.Duration) fnOpt {
	return func(r *Retrier) {
		r.LastWait = interval
		r.BackoffFn = func(r *Retrier) time.Duration { return interval }
	}
}

func WithBackoffExponential() fnOpt {
	return func(r *Retrier) {
		r.BackoffFn = func(r *Retrier) time.Duration { return r.LastWait * 2 }
	}
}
