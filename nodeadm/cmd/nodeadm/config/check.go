package config

import (
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type fileCmd struct {
	cmd        *flaggy.Subcommand
	outputPath string
}

func NewCheckCommand() cli.Command {
	cmd := flaggy.NewSubcommand("check")
	file := &fileCmd{
		cmd: cmd,
	}
	cmd.Description = "Verify configuration"
	cmd.String(&file.outputPath, "o", "output", "write validated config to mentioned file")
	return file
}

func (c *fileCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *fileCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	log.Info("Checking configuration", zap.String("source", opts.ConfigSource))
	provider, err := configprovider.BuildConfigProvider(opts.ConfigSource)
	if err != nil {
		return err
	}
	nodeConfig, err := provider.Provide()
	if err != nil {
		return err
	}
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}
	log.Info("Configuration is valid")
	if c.outputPath != "" {
		log.Info("Writing configuration", zap.String("path", c.outputPath))
		if err := writeConfigToFile(c.outputPath, &nodeConfig.Spec); err != nil {
			log.Warn("Failed to write config", zap.Error(err))
		}
	}
	return nil
}

func writeConfigToFile(outputFilePath string, nodeConfigSpec *api.NodeConfigSpec) error {
	if err := os.MkdirAll(filepath.Dir(outputFilePath), 0500); err != nil {
		return err
	}
	f, err := os.OpenFile(outputFilePath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0200)
	if err != nil {
		return err
	}
	defer func() {
		f.Close()
		os.Chmod(outputFilePath, 0400)
	}()
	return json.NewEncoder(f).Encode(nodeConfigSpec)
}
