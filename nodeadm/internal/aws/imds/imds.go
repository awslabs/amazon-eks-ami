package imds

import (
	"context"
	"io"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/ratelimit"
	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var _defaultClient *imds.Client

func init() {
	_defaultClient = NewClient(false /* do not retry 404s with default client */)
}

type IMDSProperty string

const (
	ServicesDomain IMDSProperty = "services/domain"
	LocalIPv4                   = "local-ipv4"
	MAC                         = "mac"
	MACs                        = "network/interfaces/macs/"
)

type IMDSClient interface {
	GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error)
	GetUserData(ctx context.Context) ([]byte, error)
	GetProperty(ctx context.Context, prop IMDSProperty) (string, error)
	GetPropertyBytes(ctx context.Context, prop IMDSProperty) ([]byte, error)
}

func NewClient(retry404s bool) *imds.Client {
	return imds.New(imds.Options{
		DisableDefaultTimeout: true,
		Retryer: retry.NewStandard(func(so *retry.StandardOptions) {
			so.MaxAttempts = 60
			so.MaxBackoff = 1 * time.Second
			if retry404s {
				so.Retryables = append(so.Retryables,
					&retry.RetryableHTTPStatusCode{
						Codes: map[int]struct{}{
							// allow 404s to be retried due to the rare occurrence that
							// credentials take longer to propagate through IMDS and
							// fail on the first call.
							404: {},
						},
					},
				)
			}
			// disable client-side rate-limiting
			so.RateLimiter = ratelimit.None
		}),
	})
}

func DefaultClient() IMDSClient {
	return &defaultClient{}
}

type defaultClient struct{}

func (c *defaultClient) GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error) {
	return _defaultClient.GetInstanceIdentityDocument(ctx, &imds.GetInstanceIdentityDocumentInput{})
}

func (c *defaultClient) GetUserData(ctx context.Context) ([]byte, error) {
	res, err := _defaultClient.GetUserData(ctx, &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}

func (c *defaultClient) GetProperty(ctx context.Context, prop IMDSProperty) (string, error) {
	bytes, err := c.GetPropertyBytes(ctx, prop)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func (c *defaultClient) GetPropertyBytes(ctx context.Context, prop IMDSProperty) ([]byte, error) {
	res, err := _defaultClient.GetMetadata(ctx, &imds.GetMetadataInput{Path: string(prop)})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}
