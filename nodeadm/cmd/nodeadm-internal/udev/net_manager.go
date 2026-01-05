package udev

import (
	"context"
	_ "embed"
	"fmt"
	"os"
	"path"
	"strings"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

type netManager struct {
	cmd    *flaggy.Subcommand
	iface  string
	action string

	// internal state
	selfMac    string
	primaryMac string
	imds       imds.IMDSClient
}

func NewNetManagerCommand() cli.Command {
	c := netManager{
		cmd:  flaggy.NewSubcommand("udev-net-manager"),
		imds: imds.DefaultClient(),
	}
	flaggy.String(&c.iface, "i", "interface", "the name of the interface")
	flaggy.String(&c.action, "a", "action", "the udev action")
	c.cmd.Description = "A utility for udev rules for network interfaces"
	return &c
}

func (c *netManager) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *netManager) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	if len(c.iface) == 0 {
		return fmt.Errorf("interface name cannot be empty")
	}
	ctx := context.TODO()
	log = log.With(zap.String("interface", c.iface))
	switch c.action {
	case "add":
		return c.addAction(ctx, log)
	case "remove":
		return c.removeAction(ctx, log)
	}
	return fmt.Errorf("unhandled action %q", c.action)
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
	ManagerSystemd = "io.systemd.Network"

	// NOTE: other manager names have no functional value, they only need to be
	// differentiated from the managerSystemd name.

	ManagerCNI = "cni"
)

func (c *netManager) addAction(ctx context.Context, log *zap.Logger) error {
	var err error

	if c.selfMac, err = getInterfaceMAC(c.iface); err != nil {
		return err
	}
	log.Info("found self interface mac", zap.String("address", c.selfMac))

	// this is the our first request to IMDS, so we use a client that tolerates
	// and retries 404 responses to accomodate for eventual consistency.
	if c.primaryMac, err = imds.NewClient(imds.New(true)).GetProperty(ctx, imds.MAC); err != nil {
		return err
	}
	log.Info("found primary interface mac", zap.String("address", c.primaryMac))

	identity, err := imds.DefaultClient().GetInstanceIdentityDocument(ctx)
	if err != nil {
		return err
	}
	// TODO: in the future we should communicate with another broker that checks
	// with the CNI (IPAMD) to get info on whether a given interface should be
	// managed or not.
	manager, err := NewFSBroker(identity.InstanceID).ManagerFor(c.iface)
	if err != nil {
		return fmt.Errorf("failed to determine manager: %v", err)
	}
	log.Info("resolved net manager", zap.String("name", manager))

	if manager == ManagerSystemd {
		if err := c.manageLink(ctx); err != nil {
			return err
		}

		// some default networking is required to obtain interfaces that can
		// communicate with IMDS. once we can reach IMDS and explicitly
		// configure the primary interface, we disable default networking so
		// that future links do not become managed unless we intend to do so.
		// this condition also guarantees that we only attempt to create this
		// drop-in a single time.
		if c.selfMac == c.primaryMac {
			log.Info("disabling default ec2 network configuration")
			if err := disableDefaultEc2Networking(); err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *netManager) removeAction(_ context.Context, log *zap.Logger) error {
	configPath := eksNetworkPath(c.iface)
	log.Info("removing interface network config", zap.String("path", configPath))
	return os.RemoveAll(configPath)
}

func (c *netManager) manageLink(ctx context.Context) error {
	deviceIndex, err := getDeviceIndex(ctx, c.imds, c.selfMac)
	if err != nil {
		return err
	}
	networkCard, err := getNetworkCard(ctx, c.imds, c.selfMac)
	if err != nil {
		return err
	}

	const (
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L39
		metricBase = 512
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L32
		ruleBase = 10000
	)

	// TODO: this is a temporary fix needed because of a bug in upstream systemd
	// only enable DNS for the primary interface to avoid duplicate entries
	// see: https://github.com/systemd/systemd/pull/40069
	useDNSValue := "no"
	if c.selfMac == c.primaryMac {
		useDNSValue = "yes"
	}

	templateVars := networkTemplateVars{
		MAC: c.selfMac,
		// setup route metics. this provides priority on good interfaces over
		// ones that could potentially delay startup.
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L348-L366
		Metric: metricBase + 100*networkCard + deviceIndex,
		UseDNS: useDNSValue,
	}

	// we only need to add routes/rules to interfaces beyond the primary.
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/main/lib/lib.sh#L570-L580
	if c.selfMac != c.primaryMac {
		// setup table id for use in defining default routes.
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L349
		templateVars.TableID = ruleBase + 100*networkCard + deviceIndex

		// getting the interface ip allows us to create a policy rule through
		// the gateway for the default route. we dont care about the error here,
		// because if we get a 404 then we assume this is an ipv6 network then
		// we wont setup the ip.
		//
		// TODO: no support for ipv6 today.
		if ipv4s, _ := c.imds.GetProperty(ctx, imds.LocalIPv4s(c.selfMac)); len(ipv4s) > 0 {
			// at the time we make this request, we expect no other ip addresses
			// besides the one assigned on attachment, but we can still split
			// this and take the first item since its not empty.
			ipv4 := strings.Split(ipv4s, "\n")[0]
			templateVars.InterfaceIP = strings.TrimSpace(ipv4)
		}
	}

	networkConfig, err := renderNetworkTemplate(templateVars)
	if err != nil {
		return fmt.Errorf("failed to render network template: %w", err)
	}

	return util.WriteFileWithDir(eksNetworkPath(c.iface), networkConfig, 0644)
}

func getInterfaceMAC(iface string) (string, error) {
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L34
	// #nosec G304 // read only operation on sysfs path
	macData, err := os.ReadFile(path.Join("/sys/class/net", iface, "address"))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(macData)), nil
}
