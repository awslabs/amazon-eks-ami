package configprovider

import (
	"errors"
	"fmt"

	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

var (
	ErrNoConfigInChain = errors.New("no config in chain")
)

type configProviderChain struct {
	providers []ConfigProvider
}

func (c *configProviderChain) Provide() (*internalapi.NodeConfig, error) {
	var configs []*internalapi.NodeConfig
	for idx, provider := range c.providers {
		if config, err := provider.Provide(); err != nil {
			// tolerate specific errors from certain providers when they arise in the chain
			switch provider.(type) {
			case *fileConfigProvider:
				if errors.Is(err, ErrNoConfigInDirectory) {
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
