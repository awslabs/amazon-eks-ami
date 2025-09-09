package udev

import (
	"bytes"
	"context"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

var (
	//go:embed eks-managed.network.tpl
	managedTemplateData string
	managedTemplate     = template.Must(template.New("eks-managed").Parse(managedTemplateData))

	//go:embed eks-unmanaged.network.tpl
	unmanagedTemplateData string
	unmanagedTemplate     = template.Must(template.New("eks-unmanaged").Parse(unmanagedTemplateData))
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
	mac, err := getInterfaceMAC(c.iface)
	if err != nil {
		return err
	}
	manager, err := c.determineManager()
	if err != nil {
		return fmt.Errorf("failed to determine manager: %v", err)
	}
	if manager == managerSystemd {
		if err := manageLink(c.iface, mac); err != nil {
			return err
		}
	} else {
		// TODO: after updating to a newer version of systemd we can remove this
		// and let the ID_NET_MANAGED_BY mechanism work as expected.
		if err := unmanageLink(c.iface, mac); err != nil {
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

	// NOTE: other manager names have no functional value, they only need to be
	// differentiated from the managerSystemd name.

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

func getInterfaceMAC(iface string) (string, error) {
	if len(iface) == 0 {
		return "", fmt.Errorf("interface name cannot be empty")
	}
	// https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L34
	macData, err := os.ReadFile(fmt.Sprintf("/sys/class/net/%s/address", iface))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(macData)), nil
}

func eksNetworkPath(iface string) string {
	return filepath.Join("/run/systemd/network/", fmt.Sprintf("70-eks-%s.network", iface))
}

func manageLink(iface, mac string) error {
	imdsClient := imds.NewClient(imds.New(true /* retry 404s to be resilient */))

	deviceIndexString, err := imdsClient.GetProperty(context.Background(), imds.DeviceIndex(mac))
	if err != nil {
		return err
	}
	deviceIndex, err := strconv.Atoi(deviceIndexString)
	if err != nil {
		return err
	}
	networkCardString, err := imdsClient.GetProperty(context.Background(), imds.NetworkCard(mac))
	if err != nil {
		return err
	}
	networkCard, err := strconv.Atoi(networkCardString)
	if err != nil {
		return err
	}

	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L39
	const metricBase = 512

	var buf bytes.Buffer
	if err := managedTemplate.Execute(&buf, struct {
		MAC    string
		Metric int
	}{
		MAC: mac,
		// setup route metics. this provides priority on good interfaces over
		// ones that could potentially delay startup.
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L348-L366
		Metric: metricBase + 100*networkCard + deviceIndex,
	}); err != nil {
		return err
	}

	return util.WriteFileWithDir(eksNetworkPath(iface), buf.Bytes(), 0644)
}

func unmanageLink(iface, mac string) error {
	var buf bytes.Buffer
	if err := unmanagedTemplate.Execute(&buf, struct{ MAC string }{
		MAC: mac,
	}); err != nil {
		return err
	}

	return util.WriteFileWithDir(eksNetworkPath(iface), buf.Bytes(), 0644)
}
