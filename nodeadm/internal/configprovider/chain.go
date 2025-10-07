package configprovider

import (
	"errors"
	"fmt"

	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
	"go.uber.org/zap"
)

var (
	ErrNoConfigInChain = errors.New("no config in chain")
)

type configProviderChain struct {
	providers []ConfigProvider
}

func NewConfigProviderChain(providers []ConfigProvider) *configProviderChain {
	return &configProviderChain{
		providers: providers,
	}
}

func (c *configProviderChain) Provide() (*internalapi.NodeConfig, error) {
	var configs []*internalapi.NodeConfig
	for idx, provider := range c.providers {
		if config, err := provider.Provide(); err != nil {
			zap.L().Warn("Encountered error in config provider", zap.Error(err))

			// tolerate specific errors from certain providers when they arise in the chain
			switch provider.(type) {
			case *fileConfigProvider:
				if errors.Is(err, ErrNoConfigInDirectory) {
					continue
				}
			case *userDataConfigProvider:
				if errors.Is(err, ErrNoConfigInUserData) {
					continue
				}
				// we choose to ONLY tolerate decoding errors in user-data
				// because users may not opt-in to the normal lifecycle.
				if errors.Is(err, bridge.ErrNodeConfigDecodingFailure) {
					continue
				}
			}
			return nil, fmt.Errorf("config provider at index %d failed: %v", idx, err)
		} else {
			configs = append(configs, config)
		}
	}
	if len(configs) == 0 {
		return nil, ErrNoConfigInChain
	}
	return internalapi.MergeNodeConfigs(configs)
}
