package configprovider

import (
	"fmt"
	"net/url"
)

// BuildConfigProviderChain returns a ConfigProvider that evaluates multiple config sources, in the order specified, merging the result.
func BuildConfigProviderChain(rawConfigSourceURLs []string) (ConfigProvider, error) {
	var providers []ConfigProvider
	for _, configSource := range rawConfigSourceURLs {
		provider, err := BuildConfigProvider(configSource)
		if err != nil {
			return nil, fmt.Errorf("failed to build provider from config source %q: %v", configSource, err)
		}
		providers = append(providers, provider)
	}
	return &configProviderChain{
		providers: providers,
	}, nil
}

// BuildConfigProvider returns a ConfigProvider appropriate for the given source URL.
// The source URL must have a scheme, and the supported schemes are:
// - `file`. To use configuration from the filesystem: `file:///path/to/file/or/directory`.
// - `imds`. To use configuration from the instance's user data: `imds://user-data`.
func BuildConfigProvider(rawConfigSourceURL string) (ConfigProvider, error) {
	parsedURL, err := url.Parse(rawConfigSourceURL)
	if err != nil {
		return nil, err
	}
	switch parsedURL.Scheme {
	case "imds":
		return NewUserDataConfigProvider(), nil
	case "file":
		filePath := getURLWithoutScheme(parsedURL)
		return NewFileConfigProvider(filePath), nil
	default:
		return nil, fmt.Errorf("unsupported scheme: %s", parsedURL.Scheme)
	}
}

func getURLWithoutScheme(url *url.URL) string {
	return fmt.Sprintf("%s%s", url.Host, url.Path)
}
