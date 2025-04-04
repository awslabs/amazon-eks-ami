package util

import (
	"errors"
	"fmt"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/ipamd"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type networkInterfaceOwnerCommand struct {
	cmd *flaggy.Subcommand

	interfaceId string
}

func NewNetworkInterfaceOwnerCommand() cli.Command {
	c := networkInterfaceOwnerCommand{
		cmd: flaggy.NewSubcommand("network-interface-owner"),
	}
	c.cmd.Description = "Determine the owner of a local network interface"
	c.cmd.String(&c.interfaceId, "i", "interface-id", "Network interface ID")
	return &c
}

func (c *networkInterfaceOwnerCommand) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *networkInterfaceOwnerCommand) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	enis, err := ipamd.GetENIInfos()
	if err != nil {
		if errors.Is(err, ipamd.ErrIPAMDNotAvailable) {
			log.Info("IPAMD is not available, assuming interface is not owned by it")
			return nil
		}
		return err
	} else {
		log.Info("Retrieved ENI information", zap.Reflect("enis", enis))
	}
	for _, eni := range enis.ENIs {
		if eni.ID == c.interfaceId {
			return fmt.Errorf("interface is owned by IPAMD: %+v", eni)
		}
	}
	return nil
}
