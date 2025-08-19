package api

import (
	"fmt"
	"net/url"
	"strings"
)

func ValidateNodeConfig(cfg *NodeConfig) error {
	if cfg.Spec.Cluster.Name == "" {
		return fmt.Errorf("Name is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.APIServerEndpoint == "" {
		return fmt.Errorf("Apiserver endpoint is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.CertificateAuthority == nil {
		return fmt.Errorf("Certificate authority is missing in cluster configuration")
	}
	if cfg.Spec.Cluster.CIDR == "" {
		return fmt.Errorf("CIDR is missing in cluster configuration")
	}
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		if cfg.Spec.Cluster.ID == "" {
			return fmt.Errorf("CIDR is missing in cluster configuration")
		}
	}

	// TODO: Add detailed proxy configuration validation
	if err := validateProxyOptionsBasic(cfg.Spec.Proxy); err != nil {
		return fmt.Errorf("proxy configuration validation failed: %w", err)
	}

	return nil
}

// TODO: Expand this to include detailed URL validation, NoProxy pattern validation etc
func validateProxyOptionsBasic(proxy ProxyOptions) error {
	if proxy.HTTPProxy != "" {
		if _, err := url.Parse(proxy.HTTPProxy); err != nil {
			return fmt.Errorf("invalid HTTP_PROXY URL: %w", err)
		}
	}

	if proxy.HTTPSProxy != "" {
		if _, err := url.Parse(proxy.HTTPSProxy); err != nil {
			return fmt.Errorf("invalid HTTPS_PROXY URL: %w", err)
		}
	}

	for i, pattern := range proxy.NoProxy {
		if strings.TrimSpace(pattern) == "" {
			return fmt.Errorf("empty NO_PROXY pattern at index %d", i)
		}
	}

	return nil
}
