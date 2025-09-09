package imds

import (
	"context"
	"fmt"
	"io"
	"path"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/ratelimit"
	"github.com/aws/aws-sdk-go-v2/aws/retry"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var _defaultClient *imds.Client

func init() {
	_defaultClient = New(false /* do not retry 404s with default client */)
}

type IMDSProperty string

const (
	ServicesDomain IMDSProperty = "services/domain"
	LocalIPv4      IMDSProperty = "local-ipv4"
	MAC            IMDSProperty = "mac"
	MACs           IMDSProperty = "network/interfaces/macs/"
)

var (
	DeviceIndex = func(mac string) IMDSProperty { return IMDSProperty(path.Join(string(MACs), mac, "device-number")) }
	NetworkCard = func(mac string) IMDSProperty { return IMDSProperty(path.Join(string(MACs), mac, "network-card")) }
)

type IMDSClient interface {
	GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error)
	GetUserData(ctx context.Context) ([]byte, error)
	GetProperty(ctx context.Context, prop IMDSProperty) (string, error)
}

func New(retry404s bool, fnOpts ...func(*imds.Options)) *imds.Client {
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
	}, fnOpts...)
}

func NewClient(client *imds.Client) IMDSClient {
	return &imdsClient{
		client: client,
	}
}

func DefaultClient() IMDSClient {
	return &imdsClient{
		client: _defaultClient,
	}
}

type imdsClient struct {
	client *imds.Client
}

func (c *imdsClient) GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error) {
	return c.client.GetInstanceIdentityDocument(ctx, &imds.GetInstanceIdentityDocumentInput{})
}

func (c *imdsClient) GetUserData(ctx context.Context) ([]byte, error) {
	res, err := c.client.GetUserData(ctx, &imds.GetUserDataInput{})
	if err != nil {
		return nil, err
	}
	return io.ReadAll(res.Content)
}

func (c *imdsClient) GetProperty(ctx context.Context, prop IMDSProperty) (string, error) {
	res, err := c.client.GetMetadata(ctx, &imds.GetMetadataInput{Path: string(prop)})
	if err != nil {
		return "", fmt.Errorf("metadata property path %s: %w", prop, err)
	}
	bytes, err := io.ReadAll(res.Content)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}
