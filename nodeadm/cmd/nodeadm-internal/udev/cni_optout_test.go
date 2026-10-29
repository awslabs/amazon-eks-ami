package udev

import (
	"context"
	"errors"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/smithy-go"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
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
	const (
		mac   = "0a:1b:2c:3d:4e:5f"
		eniID = "eni-0123456789abcdef0"
	)
	imdsErr := errors.New("StatusCode: 404")
	apiErr := &smithy.GenericAPIError{Code: "InvalidNetworkInterfaceID.NotFound"}
	for _, tc := range []struct {
		name    string
		imdsErr error
		enis    []ec2types.NetworkInterface
		err     error
		// empty means pending
		want string
	}{
		{name: "eni not yet in imds", imdsErr: imdsErr},
		{name: "eni not yet visible"},
		{name: "api error", err: apiErr},
		{name: "system managed", enis: taggedENI(map[string]string{systemManagedTagKey: "true"}), want: networkmanager.ManagerSystemd},
		{name: "case sensitive", enis: taggedENI(map[string]string{systemManagedTagKey: "True"}), want: networkmanager.ManagerCNI},
		{name: "explicit false", enis: taggedENI(map[string]string{systemManagedTagKey: "false"}), want: networkmanager.ManagerCNI},
		{name: "empty value", enis: taggedENI(map[string]string{systemManagedTagKey: ""}), want: networkmanager.ManagerCNI},
		{name: "unrelated tag", enis: taggedENI(map[string]string{"Name": "dataplane"})},
		{name: "cni no_manage alone", enis: taggedENI(map[string]string{"node.k8s.amazonaws.com/no_manage": "true"})},
	} {
		t.Run(tc.name, func(t *testing.T) {
			imdsClient := &imds.FakeIMDSClient{
				GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
					assert.Equal(t, imds.InterfaceID(mac), prop)
					return eniID, tc.imdsErr
				},
			}
			client := &fakeDescribeNetworkInterfaces{out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: tc.enis}, err: tc.err}
			r := &ec2TagResolver{imds: imdsClient, client: client}
			got, err := r.Resolve(context.Background(), mac)
			if tc.want == "" {
				assert.ErrorIs(t, err, errOwnershipPending)
				for _, cause := range []error{tc.imdsErr, tc.err} {
					if cause != nil {
						assert.ErrorIs(t, err, cause)
					}
				}
			} else {
				assert.NoError(t, err)
			}
			assert.Equal(t, tc.want, got)
			if tc.imdsErr != nil {
				assert.Equal(t, 0, client.calls)
				return
			}
			assert.Equal(t, 1, client.calls)
			assert.Equal(t, []string{eniID}, client.gotInput.NetworkInterfaceIds)
		})
	}
}
