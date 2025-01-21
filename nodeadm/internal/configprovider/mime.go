package configprovider

import (
	"bytes"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/mail"
	"strings"

	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	apibridge "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
)

func ParseMaybeMultipart(data []byte) (*internalapi.NodeConfig, error) {
	// if the MIME data fails to parse as a multipart document, then fall back
	// to parsing the entire userdata as the node config.
	if multipartReader, err := getMultipartReader(data); err == nil {
		config, err := ParseMultipart(multipartReader)
		if err != nil {
			return nil, err
		}
		return config, nil
	} else {
		config, err := apibridge.DecodeNodeConfig(data)
		if err != nil {
			return nil, err
		}
		return config, nil
	}
}

func ParseMultipart(userDataReader *multipart.Reader) (*internalapi.NodeConfig, error) {
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

func getMultipartReader(data []byte) (*multipart.Reader, error) {
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
