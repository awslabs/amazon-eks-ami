package util

import "time"

type conditionFn func(*int, error) bool

func ConditionRetryCount(maxAttempts int) conditionFn {
	return func(i *int, _ error) bool {
		return *i < maxAttempts
	}
}

func RetryExponentialBackoff(initial time.Duration, condFn conditionFn, fn func() error) error {
	var err error
	wait := initial
	for i := 0; condFn(&i, err); i++ {
		if err = fn(); err == nil {
			return nil
		}
		time.Sleep(wait)
		wait *= 2
	}
	return err
}
