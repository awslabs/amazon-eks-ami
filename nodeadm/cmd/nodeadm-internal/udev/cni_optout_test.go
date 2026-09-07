package udev

import (
	"context"
	"testing"

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
	eni := ec2types.NetworkInterface{}
	for k, v := range tags {
		eni.TagSet = append(eni.TagSet, ec2types.Tag{Key: aws.String(k), Value: aws.String(v)})
	}
	return eni
}

func Test_ec2TagResolver_Resolve(t *testing.T) {
	const instanceID = "i-1234567890abcdef0"
	for _, tc := range []struct {
		name string
		tags map[string]string
		want ownershipDecision
	}{
		{name: "opted out", tags: map[string]string{noManageTagKey: "true"}, want: ownershipSystemd},
		{name: "case sensitive", tags: map[string]string{noManageTagKey: "True"}, want: ownershipCNI},
		{name: "explicit false", tags: map[string]string{noManageTagKey: "false"}, want: ownershipCNI},
		{name: "empty value", tags: map[string]string{noManageTagKey: ""}, want: ownershipCNI},
		{name: "tags absent", want: ownershipPending},
		{name: "unrelated tag", tags: map[string]string{"Name": "dataplane"}, want: ownershipPending},
		{name: "instance tag alone does not settle ownership", tags: map[string]string{"node.k8s.amazonaws.com/instance_id": instanceID}, want: ownershipPending},
		{name: "another instance", tags: map[string]string{"node.k8s.amazonaws.com/instance_id": "i-other"}, want: ownershipPending},
		{name: "opt out takes precedence", tags: map[string]string{noManageTagKey: "true", "node.k8s.amazonaws.com/instance_id": instanceID}, want: ownershipSystemd},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client := &fakeDescribeNetworkInterfaces{out: &ec2.DescribeNetworkInterfacesOutput{
				NetworkInterfaces: []ec2types.NetworkInterface{eniWithTags(tc.tags)},
			}}
			r := &ec2TagResolver{client: client, instanceID: instanceID}
			got, err := r.Resolve(context.Background(), "0a:1b:2c:3d:4e:5f")
			assert.NoError(t, err)
			assert.Equal(t, tc.want, got)
			assert.Equal(t, 1, client.calls)
			assert.ElementsMatch(t, []ec2types.Filter{
				{Name: aws.String("mac-address"), Values: []string{"0a:1b:2c:3d:4e:5f"}},
				{Name: aws.String("attachment.instance-id"), Values: []string{instanceID}},
			}, client.gotInput.Filters)
		})
	}
}

func Test_fsBroker_eventualConsistency(t *testing.T) {
	// Simulate separate systemd attempts: missing ENI, missing tags, then tags.
	client := &fakeDescribeNetworkInterfaces{out: &ec2.DescribeNetworkInterfacesOutput{}}
	b := newTestBroker(t, true, true, staticResolver(&ec2TagResolver{client: client, instanceID: "i-test"}))
	for _, enis := range [][]ec2types.NetworkInterface{nil, {eniWithTags(nil)}} {
		client.out.NetworkInterfaces = enis
		_, err := b.ManagerFor(context.Background(), "ens6", "mac")
		assert.ErrorIs(t, err, errOwnershipUnknown)
		keys, err := b.cache.Keys()
		assert.NoError(t, err)
		assert.Empty(t, keys)
	}
	client.out.NetworkInterfaces = []ec2types.NetworkInterface{eniWithTags(map[string]string{noManageTagKey: "true"})}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerSystemd, manager)
	assert.Equal(t, 3, client.calls)
}

func Test_fsBroker_recoversAfterAPIError(t *testing.T) {
	for _, code := range []string{"UnauthorizedOperation", "RequestLimitExceeded", "InternalError"} {
		t.Run(code, func(t *testing.T) {
			apiErr := &smithy.GenericAPIError{Code: code, Message: "lookup failed"}
			client := &fakeDescribeNetworkInterfaces{err: apiErr}
			b := newTestBroker(t, true, true, staticResolver(&ec2TagResolver{client: client}))
			_, err := b.ManagerFor(context.Background(), "ens6", "mac")
			assert.ErrorIs(t, err, apiErr)
			client.err = nil
			client.out = &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: []ec2types.NetworkInterface{eniWithTags(map[string]string{noManageTagKey: "true"})}}
			manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
			assert.NoError(t, err)
			assert.Equal(t, ManagerSystemd, manager)
			assert.Equal(t, 2, client.calls)
		})
	}
}

func Test_fsBroker_doesNotAdoptActiveLink(t *testing.T) {
	resolver := &fakeResolver{decision: ownershipPending}
	b := newTestBroker(t, true, true, staticResolver(resolver))
	_, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.ErrorIs(t, err, errOwnershipUnknown)
	// CNI brings up the ENI while EC2 tags are still propagating.
	b.linkIsUp = func(string) (bool, error) { return true, nil }
	resolver.decision, resolver.err = ownershipSystemd, nil
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerCNI, manager)
	assert.Equal(t, 1, resolver.calls)
}

func Test_fsBroker_linkBroughtUpDuringLookup(t *testing.T) {
	b := newTestBroker(t, true, true, staticResolver(&fakeResolver{decision: ownershipSystemd}))
	checks := 0
	b.linkIsUp = func(string) (bool, error) {
		checks++
		return checks > 1, nil
	}
	manager, err := b.ManagerFor(context.Background(), "ens6", "mac")
	assert.NoError(t, err)
	assert.Equal(t, ManagerCNI, manager)
}
