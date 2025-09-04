package boothook

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
)

const SystemdNetworkdDaemonName = "systemd-networkd"

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
	log.Info("Creating daemon manager..")
	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()

	log.Info("Configuring systemd-networkd..")

	if requiresRestart, err := system.EnsureEKSNetworkConfiguration(); err != nil {
		return err
	} else if requiresRestart {
		log.Info("Restarting systemd-networkd..")
		if err := daemonManager.RestartDaemon(SystemdNetworkdDaemonName); err != nil {
			return err
		}
	}

	log.Info("Completed boot hook!")
	return nil
}
