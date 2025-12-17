package config

import (
	"fmt"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/api/v1alpha1"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type dumpCmd struct {
	cmd *flaggy.Subcommand

	configSources []string
	configCache   string
	configOutput  string
}

func NewDumpCommand() cli.Command {
	c := dumpCmd{}
	c.cmd = flaggy.NewSubcommand("dump")
	c.cmd.Description = "Dump configuration"
	cli.RegisterFlagConfigSources(c.cmd, &c.configSources)
	cli.RegisterFlagConfigCache(c.cmd, &c.configCache)
	cli.RegisterFlagConfigOutput(c.cmd, &c.configOutput)
	return &c
}

func (c *dumpCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *dumpCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	c.configSources = cli.ResolveConfigSources(c.configSources)

	if c.configOutput != "" {
		log.Info("Dumping configuration", zap.Strings("source", c.configSources), zap.String("output", c.configOutput))
	}

	nodeConfig, _, _, err := cli.ResolveConfig(log, c.configSources, c.configCache)
	if err != nil {
		return err
	}

	data, err := bridge.EncodeNodeConfig(nodeConfig, v1alpha1.GroupVersion)
	if err != nil {
		return fmt.Errorf("failed to encode config: %w", err)
	}

	if c.configOutput != "" {
		if err := util.WriteFileWithDir(c.configOutput, data, 0644); err != nil {
			return fmt.Errorf("failed to write config to file: %w", err)
		}
		log.Info("Configuration dumped")
		return nil
	}

	if _, err := os.Stdout.Write(data); err != nil {
		return fmt.Errorf("failed to write config to stdout: %w", err)
	}
	return nil
}
