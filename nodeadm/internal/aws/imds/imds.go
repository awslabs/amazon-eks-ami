package imds

import (
	"context"
	"io"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var Client *imds.Client

func init() {
	Client = imds.New(imds.Options{
		DisableDefaultTimeout: true,
		Retryer: retry.NewStandard(func(so *retry.StandardOptions) {
			so.MaxAttempts = 60
			so.MaxBackoff = 1 * time.Second
			so.Retryables = append(so.Retryables,
				&retry.RetryableHTTPStatusCode{
					Codes: map[int]struct{}{
						// Retry 404s due to the rare occurrence that
						// credentials take longer to propagate through IMDS and
						// fail on the first call.
						404: {},
					},
				},
			)
		}),
	})
}

type IMDSProperty string

const (
	ServicesDomain IMDSProperty = "services/domain"
)

func GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error) {
	return Client.GetInstanceIdentityDocument(ctx, &imds.GetInstanceIdentityDocumentInput{})
}

func GetUserData(ctx context.Context) ([]byte, error) {
	res, err := Client.GetUserData(ctx, &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}

func GetProperty(ctx context.Context, prop IMDSProperty) (string, error) {
	bytes, err := GetPropertyBytes(ctx, prop)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func GetPropertyBytes(ctx context.Context, prop IMDSProperty) ([]byte, error) {
	res, err := Client.GetMetadata(ctx, &imds.GetMetadataInput{Path: string(prop)})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}
