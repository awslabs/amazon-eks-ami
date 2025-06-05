package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/ipamd"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type udevNetManagedByCommand struct {
	cmd *flaggy.Subcommand
}

func newUdevNetManagedByCommand() cli.Command {
	c := udevNetManagedByCommand{
		cmd: flaggy.NewSubcommand("udev-net-managed-by"),
	}
	c.cmd.Description = "A filter intended to be used in udev rules for network interfaces, which identifies interfaces owned/managed by the VPC CNI"
	return &c
}

func (c *udevNetManagedByCommand) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *udevNetManagedByCommand) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	mac, err := readDeviceMAC()
	if err != nil {
		return fmt.Errorf("failed to read device MAC: %v", err)
	}
	manager, err := determineManager(mac)
	if err != nil {
		return fmt.Errorf("failed to determine manager: %v", err)
	}
	fmt.Fprint(os.Stdout, manager)
	return nil
}

const (
	managerSystemd = "io.systemd.Network"
	managerIpamd   = "ipamd"
)

func determineManager(mac string) (string, error) {
	interfaceId, err := imds.DefaultClient().GetProperty(context.TODO(), imds.IMDSProperty(fmt.Sprintf("network/interfaces/macs/%s/interface-id", mac)))
	if err != nil {
		return "", fmt.Errorf("failed to get interface ID from IMDS for MAC: %s", mac)
	}
	enis, err := ipamd.GetENIInfos()
	if err != nil {
		if errors.Is(err, ipamd.ErrIPAMDNotAvailable) {
			// IPAMD is not available, assume interface is not owned by it
			return managerSystemd, nil
		}
		return "", err
	}
	for _, eni := range enis.ENIs {
		if eni.ID == interfaceId {
			return managerIpamd, nil
		}
	}
	return managerSystemd, nil
}

func readDeviceMAC() (string, error) {
	// device attributes will be passed to this program as environment variables
	// see: https://www.freedesktop.org/software/systemd/man/latest/systemd.net-naming-scheme.html#ID_NET_NAME_MAC=prefixxAABBCCDDEEFF
	idNetNameMac := os.Getenv("ID_NET_NAME_MAC")
	if len(idNetNameMac) == 0 {
		return "", fmt.Errorf("ID_NET_NAME_MAC is not defined")
	}
	return parseIdNetNameMac(idNetNameMac)
}

// parseIdNetNameMac parses a MAC address from the value of the ID_NET_NAME_MAC udev property
// the MAC address is always returned in lower-case hex format
func parseIdNetNameMac(s string) (string, error) {
	// 2-character prefix + 'x' + 12 hex digits
	if len(s) != 15 {
		return "", fmt.Errorf("malformed ID_NET_NAME_MAC: %s", s)
	}
	mac := make([]byte, 17)
	for i, j := 3, 0; i < 15; i, j = i+1, j+1 {
		if pos := i - 3; pos > 0 && pos%2 == 0 {
			mac[j] = ':'
			j++
		}
		mac[j] = byteToLower(s[i])
	}
	return string(mac), nil
}

// byteToLower maps a single ASCII byte to lower case
func byteToLower(b byte) byte {
	if 'A' <= b && b <= 'Z' {
		b += 'a' - 'A'
	}
	return b
}
