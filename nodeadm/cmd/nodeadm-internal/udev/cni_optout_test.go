package udev

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/smithy-go"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/networkmanager"
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

func taggedENI(tags map[string]string) []ec2types.NetworkInterface {
	eni := ec2types.NetworkInterface{}
	for k, v := range tags {
		eni.TagSet = append(eni.TagSet, ec2types.Tag{Key: aws.String(k), Value: aws.String(v)})
	}
	return []ec2types.NetworkInterface{eni}
}

func Test_ec2TagResolver_Resolve(t *testing.T) {
	const instanceID = "i-1234567890abcdef0"
	apiErr := &smithy.GenericAPIError{Code: "UnauthorizedOperation"}
	for _, tc := range []struct {
		name string
		enis []ec2types.NetworkInterface
		err  error
		// empty means pending
		want string
	}{
		{name: "eni not yet visible"},
		{name: "api error", err: apiErr},
		{name: "opted out", enis: taggedENI(map[string]string{noManageTagKey: "true"}), want: networkmanager.ManagerSystemd},
		{name: "case sensitive", enis: taggedENI(map[string]string{noManageTagKey: "True"}), want: networkmanager.ManagerCNI},
		{name: "explicit false", enis: taggedENI(map[string]string{noManageTagKey: "false"}), want: networkmanager.ManagerCNI},
		{name: "empty value", enis: taggedENI(map[string]string{noManageTagKey: ""}), want: networkmanager.ManagerCNI},
		{name: "unrelated tag", enis: taggedENI(map[string]string{"Name": "dataplane"})},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client := &fakeDescribeNetworkInterfaces{out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: tc.enis}, err: tc.err}
			r := &ec2TagResolver{client: client, instanceID: instanceID}
			got, err := r.Resolve(context.Background(), "0a:1b:2c:3d:4e:5f")
			if tc.want == "" {
				assert.ErrorIs(t, err, errOwnershipPending)
				if tc.err != nil {
					assert.ErrorIs(t, err, tc.err)
				}
			} else {
				assert.NoError(t, err)
			}
			assert.Equal(t, tc.want, got)
			assert.Equal(t, 1, client.calls)
			assert.ElementsMatch(t, []ec2types.Filter{
				{Name: aws.String("mac-address"), Values: []string{"0a:1b:2c:3d:4e:5f"}},
				{Name: aws.String("attachment.instance-id"), Values: []string{instanceID}},
			}, client.gotInput.Filters)
		})
	}
}
