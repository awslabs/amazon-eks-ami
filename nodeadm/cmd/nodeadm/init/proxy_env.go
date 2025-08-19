package init

import (
	"os"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

// setProxyEnvironmentVariables configures HTTP_PROXY, HTTPS_PROXY, and NO_PROXY
// environment variables based on the provided ProxyOptions.
// This allows AWS SDK v2 to automatically use proxy configuration.
func setProxyEnvironmentVariables(proxyOpts api.ProxyOptions) {
	// Set HTTP_PROXY if configured
	if proxyOpts.HTTPProxy != "" {
		os.Setenv("HTTP_PROXY", proxyOpts.HTTPProxy)
	}

	// Set HTTPS_PROXY if configured
	if proxyOpts.HTTPSProxy != "" {
		os.Setenv("HTTPS_PROXY", proxyOpts.HTTPSProxy)
	}

	// Build NO_PROXY list from user-specified patterns
	noProxyList := buildNoProxyList(proxyOpts.NoProxy)
	if len(noProxyList) > 0 {
		os.Setenv("NO_PROXY", strings.Join(noProxyList, ","))
	}
}

// Create NO_PROXY list that includes:
// 1. User-specified NoProxy patterns
// 2. Standard localhost
func buildNoProxyList(userNoProxy []string) []string {
	noProxyList := []string{
		"localhost",
		"127.0.0.1",
	}

	for _, pattern := range userNoProxy {
		pattern = strings.TrimSpace(pattern)
		if pattern == "" {
			continue
		}

		exists := false
		for _, existing := range noProxyList {
			if existing == pattern {
				exists = true
				break
			}
		}

		if !exists {
			noProxyList = append(noProxyList, pattern)
		}
	}

	return noProxyList
}

// This can be used for cleanup or testing purposes.
func clearProxyEnvironmentVariables() {
	os.Unsetenv("HTTP_PROXY")
	os.Unsetenv("HTTPS_PROXY")
	os.Unsetenv("NO_PROXY")
}
