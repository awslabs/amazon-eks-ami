package udev

import (
	"context"
	_ "embed"
	"fmt"
	"net/http"
	"testing"

	awshttp "github.com/aws/aws-sdk-go-v2/aws/transport/http"
	"github.com/aws/smithy-go"
	smithyhttp "github.com/aws/smithy-go/transport/http"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/stretchr/testify/assert"
)

var imds404Error = &smithy.OperationError{
	OperationName: "ec2imds",
	Err: &awshttp.ResponseError{
		ResponseError: &smithyhttp.ResponseError{
			Response: &smithyhttp.Response{
				Response: &http.Response{
					StatusCode: http.StatusNotFound,
				},
			},
			Err: fmt.Errorf("request to EC2 IMDS failed"),
		},
	},
}

func Test_isNotFoundErr(t *testing.T) {
	assert.True(t, isNotFoundErr(imds404Error))
	assert.True(t, isNotFoundErr(fmt.Errorf("operation error ec2imds: GetMetadata, http response error StatusCode: 404, request to EC2 IMDS failed")))
}

func Test_IMDS(t *testing.T) {
	t.Run("DeviceIndex", func(t *testing.T) {
		imdsClient := &imds.FakeIMDSClient{
			GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
				return "2", nil
			},
		}
		deviceIndex, err := getDeviceIndex(context.TODO(), imdsClient, "mac")
		assert.NoError(t, err)
		assert.Equal(t, deviceIndex, 2)
	})

	t.Run("DeviceIndexError", func(t *testing.T) {
		imdsClient := &imds.FakeIMDSClient{
			GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
				return "", fmt.Errorf("foo")
			},
		}
		_, err := getDeviceIndex(context.TODO(), imdsClient, "mac")
		assert.Error(t, err)
	})

	t.Run("NetworkCard", func(t *testing.T) {
		imdsClient := &imds.FakeIMDSClient{
			GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
				return "2", nil
			},
		}
		networkCard, err := getNetworkCard(context.TODO(), imdsClient, "mac")
		assert.NoError(t, err)
		assert.Equal(t, networkCard, 2)
	})

	t.Run("NetworkCardError", func(t *testing.T) {
		imdsClient := &imds.FakeIMDSClient{
			GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
				return "", fmt.Errorf("foo")
			},
		}
		_, err := getNetworkCard(context.TODO(), imdsClient, "mac")
		assert.Error(t, err)
	})

	t.Run("NetworkCard404", func(t *testing.T) {
		imdsClient := &imds.FakeIMDSClient{
			GetPropertyFunc: func(ctx context.Context, prop imds.IMDSProperty) (string, error) {
				return "", imds404Error
			},
		}
		networkCard, err := getNetworkCard(context.TODO(), imdsClient, "mac")
		assert.NoError(t, err)
		assert.Equal(t, networkCard, 0)
	})
}
