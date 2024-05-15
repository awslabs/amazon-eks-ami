package imds

import (
	"context"
	"io"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var client *imds.Client

func init() {
	client = imds.New(imds.Options{
		DisableDefaultTimeout: true,
		Retryer: retry.NewStandard(func(so *retry.StandardOptions) {
			so.MaxAttempts = 15
			so.MaxBackoff = 1 * time.Second
		}),
	})
}

type IMDSProperty string

const (
	ServicesDomain IMDSProperty = "services/domain"
)

func GetUserData() ([]byte, error) {
	resp, err := client.GetUserData(context.TODO(), &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(resp.Content)
}

func GetProperty(prop IMDSProperty) (string, error) {
	bytes, err := GetPropertyBytes(prop)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func GetPropertyBytes(prop IMDSProperty) ([]byte, error) {
	res, err := client.GetMetadata(context.TODO(), &imds.GetMetadataInput{Path: string(prop)})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}
