package configprovider

import (
	"context"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/mail"
	"strings"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/api"
	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	apibridge "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
)

const nodeConfigMediaType = "application/" + api.GroupName

type imdsConfigProvider struct {
	client imds.Client
}

func NewIMDSConfigProvider() ConfigProvider {
	return &imdsConfigProvider{
		client: *imds.New(imds.Options{}),
	}
}

func (ics *imdsConfigProvider) Provide() (*internalapi.NodeConfig, error) {
	resp, err := ics.client.GetUserData(context.TODO(), &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	config, err := parseMIMEUserData(resp.Content)
	if err != nil {
		return nil, err
	}
	return config, nil
}

func parseMIMEUserData(mimeData io.Reader) (*internalapi.NodeConfig, error) {
	msg, err := mail.ReadMessage(mimeData)
	if err != nil {
		return nil, err
	}
	mediaType, params, err := mime.ParseMediaType(msg.Header.Get("Content-Type"))
	if err != nil {
		return nil, err
	}
	if !strings.HasPrefix(mediaType, "multipart/") {
		return nil, fmt.Errorf("invalid MIME media type: %s", mediaType)
	}
	userDataReader := multipart.NewReader(msg.Body, params["boundary"])
	for {
		part, err := userDataReader.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}

		if partHeader := part.Header.Get("Content-Type"); partHeader != "" {
			mediaType, _, err := mime.ParseMediaType(partHeader)
			if err != nil {
				return nil, err
			}
			if mediaType == nodeConfigMediaType {
				nodeConfigPart, err := io.ReadAll(part)
				if err != nil {
					return nil, err
				}
				data, err := apibridge.DecodeNodeConfig(nodeConfigPart)
				if err != nil {
					return nil, err
				}
				return data, nil
			}
		}
	}
	return nil, fmt.Errorf("Could not find bootstrap config data within the IMDS UserData.")
}
