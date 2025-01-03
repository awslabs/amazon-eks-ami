package config

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type dumpCmd struct {
	cmd *flaggy.Subcommand

	configSources []string
	configOutput  string
}

func NewDumpCommand() cli.Command {
	c := dumpCmd{}
	c.cmd = flaggy.NewSubcommand("dump")
	c.cmd.Description = "Dump configuration"
	cli.RegisterFlagConfigSources(c.cmd, &c.configSources)
	cli.RegisterFlagConfigOutput(c.cmd, &c.configOutput)
	return &c
}

func (c *dumpCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *dumpCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	c.configSources = cli.ResolveConfigSources(c.configSources)

	log.Info("Dumping configuration", zap.Strings("source", c.configSources))
	provider, err := configprovider.BuildConfigProviderChain(c.configSources)
	if err != nil {
		return err
	}
	nodeConfig, err := provider.Provide()
	if err != nil {
		return err
	}

	output := os.Stdout
	if c.configOutput != "" {
		output, err = os.Create(c.configOutput)
		if err != nil {
			return err
		}
		defer output.Close()
	}

	encoder := json.NewEncoder(output)
	encoder.SetIndent("", "  ")
	if err = encoder.Encode(nodeConfig); err != nil {
		return fmt.Errorf("failed to encode config: %w", err)
	}
	log.Info("Configuration dumped")
	return nil
}
