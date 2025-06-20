package ec2

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/smithy-go"
	"github.com/aws/smithy-go/middleware"
	smithytime "github.com/aws/smithy-go/time"
	smithywaiter "github.com/aws/smithy-go/waiter"
)

type InstanceCondition func(output *ec2.DescribeInstancesOutput) (bool, error)

// InstanceConditionWaiterOptions are options for InstanceConditionWaiter
type InstanceConditionWaiterOptions struct {

	// Set of options to modify how an operation is invoked. These apply to all
	// operations invoked for this client. Use functional options on operation call to
	// modify this list for per operation behavior.
	//
	// Passing options here is functionally equivalent to passing values to this
	// config's ClientOptions field that extend the inner client's APIOptions directly.
	APIOptions []func(*middleware.Stack) error

	// Functional options to be passed to all operations invoked by this client.
	//
	// Function values that modify the inner APIOptions are applied after the waiter
	// config's own APIOptions modifiers.
	ClientOptions []func(*ec2.Options)

	// MinDelay is the minimum amount of time to delay between retries. If unset,
	// InstanceRunningWaiter will use default minimum delay of 15 seconds. Note that
	// MinDelay must resolve to a value lesser than or equal to the MaxDelay.
	MinDelay time.Duration

	// MaxDelay is the maximum amount of time to delay between retries. If unset or
	// set to zero, InstanceRunningWaiter will use default max delay of 120 seconds.
	// Note that MaxDelay must resolve to value greater than or equal to the MinDelay.
	MaxDelay time.Duration

	// LogWaitAttempts is used to enable logging for waiter retry attempts
	LogWaitAttempts bool
}

// InstanceConditionWaiter waits for an instance to meet a condition
type InstanceConditionWaiter struct {
	client    ec2.DescribeInstancesAPIClient
	condition InstanceCondition
	options   InstanceConditionWaiterOptions
}

// NewInstanceConditionWaiter constructs a InstanceConditionWaiter.
func NewInstanceConditionWaiter(client ec2.DescribeInstancesAPIClient, condition InstanceCondition, optFns ...func(*InstanceConditionWaiterOptions)) *InstanceConditionWaiter {
	options := InstanceConditionWaiterOptions{}
	options.MinDelay = 15 * time.Second
	options.MaxDelay = 120 * time.Second

	for _, fn := range optFns {
		fn(&options)
	}

	return &InstanceConditionWaiter{
		client:    client,
		condition: condition,
		options:   options,
	}
}

// Wait calls the waiter function for InstanceCondition waiter. The maxWaitDur is
// the maximum wait duration the waiter will wait. The maxWaitDur is required and
// must be greater than zero.
func (w *InstanceConditionWaiter) Wait(ctx context.Context, params *ec2.DescribeInstancesInput, maxWaitDur time.Duration, optFns ...func(*InstanceConditionWaiterOptions)) error {
	_, err := w.WaitForOutput(ctx, params, maxWaitDur, optFns...)
	return err
}

// WaitForOutput calls the waiter function for InstanceConditionWaiter and returns
// the output of the successful operation. The maxWaitDur is the maximum wait
// duration the waiter will wait. The maxWaitDur is required and must be greater
// than zero.
func (w *InstanceConditionWaiter) WaitForOutput(ctx context.Context, params *ec2.DescribeInstancesInput, maxWaitDur time.Duration, optFns ...func(*InstanceConditionWaiterOptions)) (*ec2.DescribeInstancesOutput, error) {
	if maxWaitDur <= 0 {
		return nil, fmt.Errorf("maximum wait time for waiter must be greater than zero")
	}

	options := w.options
	for _, fn := range optFns {
		fn(&options)
	}

	if options.MaxDelay <= 0 {
		options.MaxDelay = 120 * time.Second
	}

	if options.MinDelay > options.MaxDelay {
		return nil, fmt.Errorf("minimum waiter delay %v must be lesser than or equal to maximum waiter delay of %v.", options.MinDelay, options.MaxDelay)
	}

	ctx, cancelFn := context.WithTimeout(ctx, maxWaitDur)
	defer cancelFn()

	logger := smithywaiter.Logger{}
	remainingTime := maxWaitDur

	var attempt int64
	for {
		attempt++
		apiOptions := options.APIOptions
		start := time.Now()

		if options.LogWaitAttempts {
			logger.Attempt = attempt
			apiOptions = append([]func(*middleware.Stack) error{}, options.APIOptions...)
			apiOptions = append(apiOptions, logger.AddLogger)
		}

		out, err := w.client.DescribeInstances(ctx, params, func(o *ec2.Options) {
			o.APIOptions = append(o.APIOptions, apiOptions...)
			for _, opt := range options.ClientOptions {
				opt(o)
			}
		})

		if err != nil {
			retryable, err := instanceRetryable(err)
			if err != nil {
				return nil, err
			}
			if !retryable {
				return out, nil
			}
		} else {
			conditionMet, err := w.condition(out)
			if err != nil {
				return nil, err
			}
			if conditionMet {
				return out, nil
			}
		}

		remainingTime -= time.Since(start)
		if remainingTime < options.MinDelay || remainingTime <= 0 {
			break
		}

		// compute exponential backoff between waiter retries
		delay, err := smithywaiter.ComputeDelay(
			attempt, options.MinDelay, options.MaxDelay, remainingTime,
		)
		if err != nil {
			return nil, fmt.Errorf("error computing waiter delay, %w", err)
		}

		remainingTime -= delay
		// sleep for the delay amount before invoking a request
		if err := smithytime.SleepWithContext(ctx, delay); err != nil {
			return nil, fmt.Errorf("request cancelled while waiting, %w", err)
		}
	}
	return nil, fmt.Errorf("exceeded max wait time for InstanceCondition waiter")
}

func instanceRetryable(err error) (bool, error) {
	if err != nil {
		var apiErr smithy.APIError
		ok := errors.As(err, &apiErr)
		if !ok {
			return false, fmt.Errorf("expected err to be of type smithy.APIError, got %w", err)
		}

		if "InvalidInstanceID.NotFound" == apiErr.ErrorCode() {
			return true, nil
		}
	}

	return true, nil
}
