package boothook

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
)

type bootHookCmd struct {
	cmd *flaggy.Subcommand
}

func NewBootHookCommand() cli.Command {
	cmd := flaggy.NewSubcommand("boot-hook")
	cmd.Description = "Apply OS level configurations expected on EKS"
	return &bootHookCmd{
		cmd: cmd,
	}
}

func (c *bootHookCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *bootHookCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	log.Info("Configuring Network Interfaces..")
	if err := system.EnsureEKSNetworkConfiguration(); err != nil {
		return err
	}
	log.Info("Completed boot hook!")
	return nil
}
