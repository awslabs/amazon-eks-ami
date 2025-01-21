package configprovider

import (
	"context"
	"fmt"

	"github.com/awslabs/amazon-eks-ami/nodeadm/api"
	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	imds "github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
)

const (
	contentTypeHeader          = "Content-Type"
	mimeBoundaryParam          = "boundary"
	multipartContentTypePrefix = "multipart/"
	nodeConfigMediaType        = "application/" + api.GroupName
)

type userDataProvider interface {
	GetUserData() ([]byte, error)
}

type imdsUserDataProvider struct{}

func (p *imdsUserDataProvider) GetUserData() ([]byte, error) {
	return imds.GetUserData(context.TODO())
}

type userDataConfigProvider struct {
	userDataProvider userDataProvider
}

func NewUserDataConfigProvider() ConfigProvider {
	return &userDataConfigProvider{
		userDataProvider: &imdsUserDataProvider{},
	}
}

func (p *userDataConfigProvider) Provide() (*internalapi.NodeConfig, error) {
	userData, err := p.userDataProvider.GetUserData()
	if err != nil {
		return nil, err
	}
	userData, err = decodeIfBase64(userData)
	if err != nil {
		return nil, fmt.Errorf("failed to decode user data: %v", err)
	}
	userData, err = decompressIfGZIP(userData)
	if err != nil {
		return nil, fmt.Errorf("failed to decompress user data: %v", err)
	}
	return ParseMaybeMultipart(userData)
}
