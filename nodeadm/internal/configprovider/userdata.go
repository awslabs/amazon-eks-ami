package configprovider

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/mail"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/api"
	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	apibridge "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
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
	return imds.GetUserData()
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

func getMIMEMultipartReader(data []byte) (*multipart.Reader, error) {
	msg, err := mail.ReadMessage(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	mediaType, params, err := mime.ParseMediaType(msg.Header.Get(contentTypeHeader))
	if err != nil {
		return nil, err
	}
	if !strings.HasPrefix(mediaType, multipartContentTypePrefix) {
		return nil, fmt.Errorf("MIME type is not multipart")
	}
	return multipart.NewReader(msg.Body, params[mimeBoundaryParam]), nil
}

func parseMultipart(userDataReader *multipart.Reader) (*internalapi.NodeConfig, error) {
	var nodeConfigs []*internalapi.NodeConfig
	for {
		part, err := userDataReader.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if partHeader := part.Header.Get(contentTypeHeader); len(partHeader) > 0 {
			mediaType, _, err := mime.ParseMediaType(partHeader)
			if err != nil {
				return nil, err
			}
			if mediaType == nodeConfigMediaType {
				nodeConfigPart, err := io.ReadAll(part)
				if err != nil {
					return nil, err
				}
				nodeConfigPart, err = decodeIfBase64(nodeConfigPart)
				if err != nil {
					return nil, err
				}
				nodeConfigPart, err = decompressIfGZIP(nodeConfigPart)
				if err != nil {
					return nil, err
				}
				decodedConfig, err := apibridge.DecodeNodeConfig(nodeConfigPart)
				if err != nil {
					return nil, err
				}
				nodeConfigs = append(nodeConfigs, decodedConfig)
			}
		}
	}
	if len(nodeConfigs) > 0 {
		var config = nodeConfigs[0]
		for _, nodeConfig := range nodeConfigs[1:] {
			if err := config.Merge(nodeConfig); err != nil {
				return nil, err
			}
		}
		return config, nil
	} else {
		return nil, fmt.Errorf("could not find NodeConfig within UserData")
	}
}

func decodeIfBase64(data []byte) ([]byte, error) {
	e := base64.StdEncoding
	maxDecodedLen := e.DecodedLen(len(data))
	decodedData := make([]byte, maxDecodedLen)
	decodedLen, err := e.Decode(decodedData, data)
	if err != nil {
		return data, nil
	}
	return decodedData[:decodedLen], nil
}

// https://en.wikipedia.org/wiki/Gzip
const gzipMagicNumber = uint16(0x1f8b)

func decompressIfGZIP(data []byte) ([]byte, error) {
	if len(data) < 2 {
		return data, nil
	}
	preamble := uint16(data[0])<<8 | uint16(data[1])
	if preamble == gzipMagicNumber {
		reader, err := gzip.NewReader(bytes.NewReader(data))
		if err != nil {
			return nil, fmt.Errorf("failed to create GZIP reader: %v", err)
		}
		if decompressed, err := io.ReadAll(reader); err != nil {
			return nil, fmt.Errorf("failed to read from GZIP reader: %v", err)
		} else {
			return decompressed, nil
		}
	}
	return data, nil
}
