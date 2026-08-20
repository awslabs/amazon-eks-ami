package cli

import (
	"context"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type CommandContainer interface {
	AddCommand(Command)
	Flaggy() *flaggy.Subcommand
	Run(ctx context.Context, log *zap.Logger, opts *GlobalOptions) error
	AsCommand() Command
}

var _ Command = &cmdContainer{}

type cmdContainer struct {
	cmd  *flaggy.Subcommand
	cmds []Command
}

func NewCommandContainer(name, description string) CommandContainer {
	cmd := flaggy.NewSubcommand(name)
	cmd.Description = description
	return &cmdContainer{
		cmd: cmd,
	}
}

func (c *cmdContainer) AddCommand(cmd Command) {
	c.cmds = append(c.cmds, cmd)
	c.cmd.AttachSubcommand(cmd.Flaggy(), 1)
}

func (c *cmdContainer) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *cmdContainer) Run(ctx context.Context, log *zap.Logger, opts *GlobalOptions) error {
	for _, cmd := range c.cmds {
		if cmd.Flaggy().Used {
			return cmd.Run(ctx, log, opts)
		}
	}
	flaggy.ShowHelpAndExit("No command specified")
	return nil
}

func (c *cmdContainer) AsCommand() Command {
	return c
}
