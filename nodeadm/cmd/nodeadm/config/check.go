package config

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type checkCmd struct {
	cmd *flaggy.Subcommand

	configSources []string
}

func NewCheckCommand() cli.Command {
	c := checkCmd{}
	c.cmd = flaggy.NewSubcommand("check")
	c.cmd.Description = "Verify configuration"
	cli.RegisterFlagConfigSources(c.cmd, &c.configSources)
	return &c
}

func (c *checkCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *checkCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	c.configSources = cli.ResolveConfigSources(c.configSources)

	log.Info("Checking configuration", zap.Strings("source", c.configSources))
	provider, err := configprovider.BuildConfigProviderChain(c.configSources)
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
	return nil
}
