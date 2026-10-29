package ec2

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
	gotInput *ec2.DescribeNetworkInterfacesInput
}

func (f *fakeDescribeNetworkInterfaces) DescribeNetworkInterfaces(ctx context.Context, params *ec2.DescribeNetworkInterfacesInput, optFns ...func(*ec2.Options)) (*ec2.DescribeNetworkInterfacesOutput, error) {
	f.gotInput = params
	return f.out, f.err
}

func TestGetNetworkInterfaceTags(t *testing.T) {
	const eniID = "eni-0123456789abcdef0"
	apiErr := &smithy.GenericAPIError{Code: "InvalidNetworkInterfaceID.NotFound"}
	for _, tc := range []struct {
		name string
		enis []ec2types.NetworkInterface
		err  error
		want map[string]string
	}{
		{name: "no interfaces", want: map[string]string{}},
		{name: "untagged", enis: []ec2types.NetworkInterface{{}}, want: map[string]string{}},
		{
			name: "tagged",
			enis: []ec2types.NetworkInterface{{TagSet: []ec2types.Tag{
				{Key: aws.String("Name"), Value: aws.String("dataplane")},
				{Key: aws.String("empty"), Value: aws.String("")},
			}}},
			want: map[string]string{"Name": "dataplane", "empty": ""},
		},
		{name: "api error", err: apiErr},
	} {
		t.Run(tc.name, func(t *testing.T) {
			client := &fakeDescribeNetworkInterfaces{out: &ec2.DescribeNetworkInterfacesOutput{NetworkInterfaces: tc.enis}, err: tc.err}
			got, err := GetNetworkInterfaceTags(context.Background(), client, eniID)
			if tc.err != nil {
				assert.ErrorIs(t, err, tc.err)
			} else {
				assert.NoError(t, err)
			}
			assert.Equal(t, tc.want, got)
			assert.Equal(t, []string{eniID}, client.gotInput.NetworkInterfaceIds)
			assert.Empty(t, client.gotInput.Filters)
		})
	}
}
