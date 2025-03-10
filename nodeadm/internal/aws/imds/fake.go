package imds

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var _ IMDSClient = &FakeIMDSClient{}

type FakeIMDSClient struct {
	GetPropertyFunc                 func(ctx context.Context, prop IMDSProperty) (string, error)
	GetPropertyBytesFunc            func(ctx context.Context, prop IMDSProperty) ([]byte, error)
	GetUserDataFunc                 func(ctx context.Context) ([]byte, error)
	GetInstanceIdentityDocumentFunc func(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error)
}

// GetInstanceIdentityDocument implements IMDSClient.
func (f *FakeIMDSClient) GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error) {
	if f.GetInstanceIdentityDocumentFunc == nil {
		panic("unimplemented")
	}
	return f.GetInstanceIdentityDocumentFunc(ctx)
}

// GetProperty implements IMDSClient.
func (f *FakeIMDSClient) GetProperty(ctx context.Context, prop IMDSProperty) (string, error) {
	if f.GetPropertyFunc == nil {
		panic("unimplemented")
	}
	return f.GetPropertyFunc(ctx, prop)
}

// GetPropertyBytes implements IMDSClient.
func (f *FakeIMDSClient) GetPropertyBytes(ctx context.Context, prop IMDSProperty) ([]byte, error) {
	if f.GetPropertyBytesFunc == nil {
		panic("unimplemented")
	}
	return f.GetPropertyBytesFunc(ctx, prop)
}

// GetUserData implements IMDSClient.
func (f *FakeIMDSClient) GetUserData(ctx context.Context) ([]byte, error) {
	if f.GetUserDataFunc == nil {
		panic("unimplemented")
	}
	return f.GetUserDataFunc(ctx)
}
