package nvidiacontainerruntime

import (
	"errors"
	"io/fs"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
)

const (
	configPath         = "/etc/nvidia-container-runtime/config.toml"
	originalConfigPath = "/etc/nvidia-container-runtime/.config.toml.orig"
	configPerm         = 0644
)

func NewConfigAspect() system.SystemAspect {
	return &configAspect{}
}

type configAspect struct{}

func (a *configAspect) Name() string {
	return "nvidia-container-runtime"
}

func (a *configAspect) Setup(cfg *api.NodeConfig) error {
	userConfig := cfg.Spec.NvidiaContainerRuntime.Config
	runtimeInstalled, err := util.IsFilePathExists(util.NvidiaContainerRuntimeBinaryPath)
	if err != nil {
		return err
	}
	if !runtimeInstalled {
		if len(userConfig) > 0 {
			zap.L().Warn("Skipping NVIDIA container runtime config, runtime not found", zap.String("path", util.NvidiaContainerRuntimeBinaryPath))
		}
		return nil
	}
	return updateConfig(configPath, originalConfigPath, userConfig)
}

// updateConfig merges the user config over a copy of the original file
// (originalConfigPath), taken the first time nodeadm changes it. Without the
// baseline copy, keys later removed from the user config would stay set, and custom AMIs can
// ship their own config that we don't want to lose. The original is restored
// once the user config is removed.
func updateConfig(configPath, originalConfigPath string, userConfig api.NvidiaContainerRuntimeConfig) error {
	// #nosec G304 // constant NVIDIA container runtime original config path
	originalConfig, err := os.ReadFile(originalConfigPath)
	originalSaved := err == nil
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}

	if len(userConfig) == 0 {
		if !originalSaved {
			return nil
		}
		zap.L().Info("Restoring original NVIDIA container runtime config..", zap.String("path", configPath))
		if err := util.WriteFileWithDir(configPath, originalConfig, configPerm); err != nil {
			return err
		}
		return os.Remove(originalConfigPath)
	}

	if !originalSaved {
		// #nosec G304 // constant NVIDIA container runtime config path
		originalConfig, err = os.ReadFile(configPath)
		if err != nil && !errors.Is(err, fs.ErrNotExist) {
			return err
		}
		if err := util.WriteFileWithDir(originalConfigPath, originalConfig, configPerm); err != nil {
			return err
		}
	}
	config, err := combineConfigs(originalConfig, userConfig)
	if err != nil {
		return err
	}

	zap.L().Info("Writing NVIDIA container runtime config to file..", zap.String("path", configPath))
	return util.WriteFileWithDir(configPath, config, configPerm)
}

func combineConfigs(existingConfig []byte, userConfig api.NvidiaContainerRuntimeConfig) ([]byte, error) {
	configMap, err := util.Merge(existingConfig, []byte(userConfig), toml.Marshal, toml.Unmarshal)
	if err != nil {
		return nil, err
	}
	return toml.Marshal(configMap)
}
