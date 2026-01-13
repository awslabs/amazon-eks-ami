package cli

import (
	"errors"
	"os"
	"reflect"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"

	"go.uber.org/zap"
)

// ResolveConfig returns either the cached config or the provided config chain.
func ResolveConfig(log *zap.Logger, rawConfigSourceURLs []string, configCachePath string) (cfg *api.NodeConfig, isChanged bool, shouldEnrichConfig bool, err error) {
	var cachedConfig *api.NodeConfig
	shouldEnrichConfig = false

	if len(configCachePath) > 0 {
		config, err := LoadCachedConfig(configCachePath)
		if err != nil {
			log.Warn("failed to load cached config", zap.Error(err))
		} else {
			cachedConfig = config
		}
	}

	provider, err := configprovider.BuildConfigProviderChain(rawConfigSourceURLs)
	if err != nil {
		return nil, false, shouldEnrichConfig, err
	}
	nodeConfig, err := provider.Provide()
	// if the error is just that no config is provided, then attempt to use the
	// cached config as a fallback. otherwise, treat this as a fatal error.
	if errors.Is(err, configprovider.ErrNoConfigInChain) && cachedConfig != nil {
		log.Warn("Falling back to cached config...")
		return cachedConfig, false, shouldEnrichConfig, nil
	} else if err != nil {
		return nil, false, shouldEnrichConfig, err
	}

	// if the cached and the provider config specs are the same, we'll just
	// use the cached spec because it also has the internal NodeConfig
	// .status information cached.
	//
	// if perf of reflect.DeepEqual becomes an issue, look into something like: https://github.com/Wind-River/deepequal-gen
	if cachedConfig != nil && reflect.DeepEqual(nodeConfig.Spec, cachedConfig.Spec) {
		return cachedConfig, false, shouldEnrichConfig, nil
	}

	// If the code reaches here it means that either no-config is cached (isChanged = false)
	// Or the cache exists and the cached spec does not match the node spec (isChanged = true)
	// In both cases, the config should be enriched
	shouldEnrichConfig = true

	// we return the presence of a cache as the `isChanged` value, because if we
	// had a cache hit and didnt use it, it's because we have a modified config.
	return nodeConfig, cachedConfig != nil, shouldEnrichConfig, nil
}

func LoadCachedConfig(path string) (*api.NodeConfig, error) {
	// #nosec G304 // intended mechanism to read user-provided config file
	nodeConfigData, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	gvk := bridge.InternalGroupVersion.WithKind(api.KindNodeConfig)
	return bridge.DecodeNodeConfig(nodeConfigData, &gvk)
}

func SaveCachedConfig(cfg *api.NodeConfig, path string) error {
	data, err := bridge.EncodeInternalNodeConfig(cfg)
	if err != nil {
		return err
	}
	return util.WriteFileWithDir(path, data, 0644)
}
