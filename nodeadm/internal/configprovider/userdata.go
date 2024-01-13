package configprovider

import (
	"bytes"
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

type userDataConfigProvider struct {
	imdsClient *imds.Client
}

func NewUserDataConfigProvider() ConfigProvider {
	return &userDataConfigProvider{
		imdsClient: imds.New(imds.Options{}),
	}
}

func (ics *userDataConfigProvider) Provide() (*internalapi.NodeConfig, error) {
	userData, err := ics.getUserData()
	if err != nil {
		return nil, err
	}
	// if the MIME data fails to parse as a multipart document, then fall back
	// to parsing the entire userdata as the node config.
	if multipartReader, err := getMIMEMultipartReader(userData); err == nil {
		config, err := parseMultipart(multipartReader)
		if err != nil {
			return nil, err
		}
		return config, nil
	} else {
		config, err := apibridge.DecodeNodeConfig(userData)
		if err != nil {
			return nil, err
		}
		return config, nil
	}
}

func (ics userDataConfigProvider) getUserData() ([]byte, error) {
	resp, err := ics.imdsClient.GetUserData(context.TODO(), &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(resp.Content)
}

func getMIMEMultipartReader(data []byte) (*multipart.Reader, error) {
	msg, err := mail.ReadMessage(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	mediaType, params, err := mime.ParseMediaType(msg.Header.Get("Content-Type"))
	if err != nil {
		return nil, err
	}
	if !strings.HasPrefix(mediaType, "multipart/") {
		return nil, fmt.Errorf("MIME type is not multipart")
	}
	return multipart.NewReader(msg.Body, params["boundary"]), nil
}

func parseMultipart(userDataReader *multipart.Reader) (*internalapi.NodeConfig, error) {
	var config *internalapi.NodeConfig
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
				if config != nil {
					return nil, fmt.Errorf("Found multiple node bootstrap configurations in the UserData")
				}
				nodeConfigPart, err := io.ReadAll(part)
				if err != nil {
					return nil, err
				}
				config, err = apibridge.DecodeNodeConfig(nodeConfigPart)
				if err != nil {
					return nil, err
				}
			}
		}
	}
	if config != nil {
		return config, nil
	} else {
		return nil, fmt.Errorf("Could not find node bootstrap config within the UserData")
	}
}
