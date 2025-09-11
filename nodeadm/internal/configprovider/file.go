package configprovider

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

var (
	ErrNoConfigInDirectory = errors.New("no config found in directory")
)

type fileConfigProvider struct {
	path string
}

func NewFileConfigProvider(path string) ConfigProvider {
	return &fileConfigProvider{
		path: path,
	}
}

func (fcs *fileConfigProvider) Provide() (*internalapi.NodeConfig, error) {
	info, err := os.Stat(fcs.path)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		return fcs.provideFromDirectory()
	}
	return fcs.parseConfigFile(fcs.path)
}

func (fcs *fileConfigProvider) parseConfigFile(filePath string) (*internalapi.NodeConfig, error) {
	// #nosec G304 // intended mechanism to read user-provided config file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	return ParseMaybeMultipart(data)
}

func (fcs *fileConfigProvider) provideFromDirectory() (*internalapi.NodeConfig, error) {
	entries, err := os.ReadDir(fcs.path)
	if err != nil {
		return nil, err
	}
	var configFiles []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if fcs.isConfigFile(name) {
			configFiles = append(configFiles, name)
		}
	}
	if len(configFiles) == 0 {
		return nil, ErrNoConfigInDirectory
	}
	var nodeConfigs []*internalapi.NodeConfig
	for _, filename := range configFiles {
		filePath := filepath.Join(fcs.path, filename)
		config, err := fcs.parseConfigFile(filePath)
		if err != nil {
			return nil, fmt.Errorf("failed to parse config file %s: %w", filename, err)
		}
		nodeConfigs = append(nodeConfigs, config)
	}
	if len(nodeConfigs) == 0 {
		return nil, fmt.Errorf("no valid configuration found in directory: %s", fcs.path)
	}
	config := nodeConfigs[0]
	for _, nodeConfig := range nodeConfigs[1:] {
		if err := config.Merge(nodeConfig); err != nil {
			return nil, fmt.Errorf("failed to merge configuration: %w", err)
		}
	}
	return config, nil
}

func (fcs *fileConfigProvider) isConfigFile(filename string) bool {
	lower := strings.ToLower(filename)
	for _, ext := range []string{".yaml", ".yml", ".json"} {
		if strings.HasSuffix(lower, ext) {
			return true
		}
	}
	return false
}
