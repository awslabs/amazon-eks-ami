package udev

import (
	"errors"
	"fmt"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type netManagedByCommand struct {
	cmd *flaggy.Subcommand
}

func NewNetManagedByCommand() cli.Command {
	c := netManagedByCommand{
		cmd: flaggy.NewSubcommand("udev-net-managed-by"),
	}
	c.cmd.Description = "A filter intended to be used in udev rules for network interfaces, which identifies interfaces owned/managed by the VPC CNI"
	return &c
}

func (c *netManagedByCommand) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *netManagedByCommand) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	manager, err := c.determineManager()
	if err != nil {
		return fmt.Errorf("failed to determine manager: %v", err)
	}
	_, err = fmt.Fprint(os.Stdout, manager)
	return err
}

const (
	// systemd reads udev properties to tell if the interface link should be
	// managed. by default it assumes they should be managed, but if the
	// 'ID_NET_MANAGED_BY' property exists and its value is not equal to
	// 'io.systemd.Network', systemd is forced to stop managing the link.
	//
	// see: https://github.com/systemd/systemd/blob/9709deba913c9c2c2e9764bcded35c6081b05197/src/network/networkd-link.c#L1372-L1396
	managerSystemd = "io.systemd.Network"
	// this name has no functional meaning, it only needs to be differentiated
	// from the value 'io.systemd.Network'.
	managerIpamd = "ipamd"
)

func (c *netManagedByCommand) determineManager() (string, error) {
	// the goal is to return 'io.systemd.Network' ONLY for interfaces present at
	// boot, which is before the CNI has started configuring the node.

	// TODO: this code checks whether cloud-init has finished booting the node,
	// which is indicative of most user-initiated actions being completed. in
	// the future we should communicate with another process to get an answer on
	// whether this interface is managed or not.
	const cloudInitBootResultPath = "/run/cloud-init/result.json"
	if _, err := os.Stat(cloudInitBootResultPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return managerSystemd, nil
		}
		return "", err
	}
	return managerIpamd, nil
}
