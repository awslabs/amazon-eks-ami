package imds

import (
	"context"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws/retry"
	awshttp "github.com/aws/aws-sdk-go-v2/aws/transport/http"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
)

var Client *imds.Client

// This function is a wrapper around the default `http.ProxyFromEnvironment` function
// which caches the proxy variables in environment when first invoked, thus preventing subsequent
// configuration attempts of http proxy via derived from user-data. Since, the first outbound
// API call in nodeadm is to the IMDS for fetching user-data, we bypass caching.
// Ref: https://github.com/golang/go/blob/ba1109feb515c2eb013399f53be5f17cfe1f189f/src/net/http/transport.go#L506
func dynamicProxyFunc(req *http.Request) (*url.URL, error) {
	// Link-local addresses do not need to be going through a proxy
	if req.URL.Host == "169.254.169.254" || req.URL.Host == "[fd00:ec2::254]" {
		return nil, nil
	}

	return http.ProxyFromEnvironment(req)
}

func init() {
	// Create HTTP client with dynamic proxy function
	httpClient := awshttp.NewBuildableClient().WithTransportOptions(func(tr *http.Transport) {
		tr.Proxy = dynamicProxyFunc
	})

	Client = imds.New(imds.Options{
		HTTPClient:            httpClient,
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
