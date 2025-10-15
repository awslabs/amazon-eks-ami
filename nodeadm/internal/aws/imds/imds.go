package imds

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/ratelimit"
	"github.com/aws/aws-sdk-go-v2/aws/retry"
	awshttp "github.com/aws/aws-sdk-go-v2/aws/transport/http"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var _defaultClient *imds.Client

// This function is a wrapper around the default `http.ProxyFromEnvironment` function
// which cachces the proxy variables in environment when first invoked thus, preventing subsequent
// configuration attempts of http proxy via derived from user-data. Since, the first outbound
// API call in nodeadm is to the IMDS for fetching user-data, we bypass caching.
// Ref: https://github.com/golang/go/blob/master/src/net/http/transport.go#L499
func dynamicProxyFunc(req *http.Request) (*url.URL, error) {
	// Link-local addresses do not need to be going through a proxy
	if req.URL.Host == "169.254.169.254" || req.URL.Host == "[fd00:ec2::254]" {
		return nil, nil
	}

	return http.ProxyFromEnvironment(req)
}

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
	LocalIPv4s  = func(mac string) IMDSProperty { return IMDSProperty(path.Join(string(MACs), mac, "local-ipv4s")) }
)

type IMDSClient interface {
	GetInstanceIdentityDocument(ctx context.Context) (*imds.GetInstanceIdentityDocumentOutput, error)
	GetUserData(ctx context.Context) ([]byte, error)
	GetProperty(ctx context.Context, prop IMDSProperty) (string, error)
}

func New(retry404s bool, fnOpts ...func(*imds.Options)) *imds.Client {
	// Create HTTP client with dynamic proxy function
	httpClient := awshttp.NewBuildableClient().WithTransportOptions(func(tr *http.Transport) {
		tr.Proxy = dynamicProxyFunc
	})

	return imds.New(imds.Options{
		HTTPClient:            httpClient,
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
		return "", fmt.Errorf("metadata property path %q: %w", prop, err)
	}
	bytes, err := io.ReadAll(res.Content)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}
