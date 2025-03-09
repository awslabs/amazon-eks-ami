package config

import (
	"encoding/json"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type dumpCmd struct {
	cmd *flaggy.Subcommand
}

func NewDumpCommand() cli.Command {
	cmd := flaggy.NewSubcommand("dump")
	cmd.Description = "Dump configuration"
	return &dumpCmd{
		cmd: cmd,
	}
}

func (c *dumpCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *dumpCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	log.Info("Dumping configuration", zap.String("source", opts.ConfigSource))
	provider, err := configprovider.BuildConfigProvider(opts.ConfigSource)
	if err != nil {
		return err
	}
	config, err := provider.Provide()
	if err != nil {
		return err
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err = encoder.Encode(config); err != nil {
		return err
	}
	log.Info("Configuration dumped")
	return nil
}
