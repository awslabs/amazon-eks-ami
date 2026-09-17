package bootbook

import (
	"context"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/cmd/nodeadm-internal/udev"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
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

func (c *bootHookCmd) Run(ctx context.Context, log *zap.Logger, opts *cli.GlobalOptions) error {
	identity, err := imds.NewClient(imds.New(true)).GetInstanceIdentityDocument(ctx)
	if err != nil {
		return err
	}
	managedInterfaces, err := udev.CachedManagedInterfaces(identity.InstanceID)
	if err != nil {
		return err
	}
	log.Info("Waiting for consistent network interfaces..")
	if err := system.EnsureEKSNetworkConfiguration(ctx, managedInterfaces); err != nil {
		return err
	}
	log.Info("Completed boot hook!")
	return nil
}
