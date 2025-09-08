package udev

import (
	_ "embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type netManagedByCommand struct {
	cmd   *flaggy.Subcommand
	iface string
}

func NewNetManagedByCommand() cli.Command {
	c := netManagedByCommand{
		cmd: flaggy.NewSubcommand("udev-net-managed-by"),
	}
	flaggy.String(&c.iface, "i", "interface", "name of the interface")
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
	// TODO: after updating to a newer version of systemd we can remove this and
	// let the ID_NET_MANAGED_BY mechanism work as expected.
	if manager != managerSystemd {
		if err := unmanageLink(c.iface); err != nil {
			return err
		}
	}
	_, err = fmt.Fprint(os.Stdout, manager)
	return err
}

const (
	// in a future version of systemd (v258+?) the network manager reads udev
	// properties to tell if the interface link should be managed. by default it
	// assumes they should be, but if the 'ID_NET_MANAGED_BY' property exists
	// and its value is not equal to 'io.systemd.Network', systemd is forced to
	// stop managing the link.
	//
	// see: https://github.com/systemd/systemd/pull/29782
	// see: https://github.com/systemd/systemd/blob/9709deba913c9c2c2e9764bcded35c6081b05197/src/network/networkd-link.c#L1372-L1396
	managerSystemd = "io.systemd.Network"

	// NOTE: other manager names have no functional value, they only needs to be
	// differentiated from the original 'io.systemd.Network' name.

	managerIpamd = "ipamd"
)

func (c *netManagedByCommand) determineManager() (string, error) {
	// TODO: for now the goal is just to return 'io.systemd.Network' ONLY for
	// interfaces present at boot, before the CNI is able to start managing
	// network interfaces for the node.

	// TODO: this code checks whether cloud-init has finished booting the node,
	// which is indicative of most user-influenced actions being completed. in
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

func unmanageLink(iface string) error {
	if len(iface) == 0 {
		return fmt.Errorf("interface name cannot be empty")
	}
	// we're adding this to the same drop-in directory that ec2-net-utils uses,
	// allowing us to piggy-back on the same removal lifecycle.
	//
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L61-L68
	linkPath := filepath.Join("/run/systemd/network/", fmt.Sprintf("70-%s.network.d", iface), "unmanaged.conf")
	// see: https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html#Unmanaged=
	return util.WriteFileWithDir(linkPath, []byte("[Link]\nUnmanaged=yes"), 0644)
}
