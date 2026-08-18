package udev

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/smithy-go"
	"github.com/stretchr/testify/assert"
)

type fakeDescribeNetworkInterfaces struct {
	out      *ec2.DescribeNetworkInterfacesOutput
	err      error
	calls    int
	gotInput *ec2.DescribeNetworkInterfacesInput
}

func (f *fakeDescribeNetworkInterfaces) DescribeNetworkInterfaces(ctx context.Context, params *ec2.DescribeNetworkInterfacesInput, optFns ...func(*ec2.Options)) (*ec2.DescribeNetworkInterfacesOutput, error) {
	f.calls++
	f.gotInput = params
	return f.out, f.err
}

func eniWithTags(tags map[string]string) ec2types.NetworkInterface {
	var ts []ec2types.Tag
	for k, v := range tags {
		ts = append(ts, ec2types.Tag{Key: aws.String(k), Value: aws.String(v)})
	}
	return ec2types.NetworkInterface{TagSet: ts}
}

func Test_ec2TagResolver_IsOptedOut(t *testing.T) {
	tests := []struct {
		name          string
		timeout       time.Duration // if non-zero, the subtest creates a context with this deadline
		out           *ec2.DescribeNetworkInterfacesOutput
		err           error
		wantErr       bool
		wantPermanent bool
		wantOptOut    bool
		wantCalls     int
	}{
		{
			name: "no_manage true",
			out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: []ec2types.NetworkInterface{
				eniWithTags(map[string]string{noManageTagKey: "true"}),
			}},
			wantOptOut: true,
			wantCalls:  1,
		},
		{
			// IPAMD compares case-sensitively, so a non-lowercase value leaves the
			// ENI CNI-managed; adopting it would give it two managers.
			name: "no_manage non-lowercase value stays CNI-managed",
			out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: []ec2types.NetworkInterface{
				eniWithTags(map[string]string{noManageTagKey: "True"}),
			}},
			wantOptOut: false,
			wantCalls:  1,
		},
		{
			name: "no_manage false",
			out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: []ec2types.NetworkInterface{
				eniWithTags(map[string]string{noManageTagKey: "false"}),
			}},
			wantOptOut: false,
			wantCalls:  1,
		},
		{
			name: "tag absent",
			out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: []ec2types.NetworkInterface{
				eniWithTags(map[string]string{"Name": "dataplane"}),
			}},
			wantOptOut: false,
			wantCalls:  1,
		},
		{
			// an empty result means the ENI isn't visible via the eventually
			// consistent EC2 API yet; retry until the caller's deadline, then error
			// rather than let a wrong decision get cached.
			name:      "no interfaces returned retries until deadline",
			timeout:   50 * time.Millisecond,
			out:       &ec2.DescribeNetworkInterfacesOutput{},
			wantErr:   true,
			wantCalls: 1, // at least one attempt before the deadline fires
		},
		{
			name:      "api error",
			err:       errors.New("boom"),
			wantErr:   true,
			wantCalls: 1,
		},
		{
			// an IAM denial will not resolve on retry, so it is flagged for an
			// actionable log line rather than retried to the deadline.
			name:          "unauthorized api error is permanent",
			err:           &smithy.GenericAPIError{Code: "UnauthorizedOperation", Message: "not authorized"},
			wantErr:       true,
			wantPermanent: true,
			wantCalls:     1,
		},
		{
			// throttling/5xx/unknown codes must stay unclassified so a transient
			// failure is not mistaken for a permanent one.
			name:      "throttling api error is not permanent",
			err:       &smithy.GenericAPIError{Code: "RequestLimitExceeded", Message: "slow down"},
			wantErr:   true,
			wantCalls: 1,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			ctx := context.Background()
			if tc.timeout > 0 {
				var cancel context.CancelFunc
				ctx, cancel = context.WithTimeout(ctx, tc.timeout)
				t.Cleanup(cancel)
			}
			fake := &fakeDescribeNetworkInterfaces{out: tc.out, err: tc.err}
			r := &ec2TagResolver{client: fake, instanceID: "i-1234567890abcdef0"}

			got, err := r.IsOptedOut(ctx, "0a:1b:2c:3d:4e:5f")
			if tc.wantErr {
				assert.Error(t, err)
				assert.GreaterOrEqual(t, fake.calls, tc.wantCalls)
				assert.Equal(t, tc.wantPermanent, errors.Is(err, ErrPermanentOptOutLookup))
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tc.wantOptOut, got)
			assert.Equal(t, tc.wantCalls, fake.calls)
			// the lookup must be scoped to both the MAC and this instance.
			assert.Len(t, fake.gotInput.Filters, 2)
		})
	}
}
