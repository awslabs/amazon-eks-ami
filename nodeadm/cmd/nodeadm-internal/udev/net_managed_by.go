package udev

import (
	"bytes"
	"context"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

var (
	//go:embed eks-managed.network.tpl
	managedTemplateData string
	managedTemplate     = template.Must(template.New("eks-managed").Parse(managedTemplateData))

	//go:embed eks-unmanaged.network.tpl
	unmanagedTemplateData string
	unmanagedTemplate     = template.Must(template.New("eks-unmanaged").Parse(unmanagedTemplateData))
)

type netManager struct {
	cmd    *flaggy.Subcommand
	iface  string
	action string
}

func NewNetManagerCommand() cli.Command {
	c := netManager{
		cmd: flaggy.NewSubcommand("udev-net-manager"),
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
	log = log.With(zap.String("interface", c.iface))
	switch c.action {
	case "add":
		return c.addAction(log)
	case "remove":
		return c.removeAction(log)
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
	managerSystemd = "io.systemd.Network"

	// NOTE: other manager names have no functional value, they only need to be
	// differentiated from the managerSystemd name.

	managerIpamd = "ipamd"
)

func (c *netManager) removeAction(log *zap.Logger) error {
	configPath := eksNetworkPath(c.iface)
	log.Info("removing interface network config", zap.String("configPath", configPath))
	return os.RemoveAll(configPath)
}

func (c *netManager) addAction(log *zap.Logger) error {
	log.Info("fetching interface mac")
	mac, err := getInterfaceMAC(c.iface)
	if err != nil {
		return err
	}
	log.Info("found interface mac", zap.String("mac", mac))
	manager, err := c.determineManager()
	if err != nil {
		return fmt.Errorf("failed to determine manager: %v", err)
	}
	log.Info("detected manager", zap.String("manager", manager))
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
	return nil
}

func (c *netManager) determineManager() (string, error) {
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
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/bin/setup-policy-routes.sh#L34
	// #nosec G304 // read only operation on sysfs path
	macData, err := os.ReadFile(path.Join("/sys/class/net/", iface, "address"))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(macData)), nil
}

func eksNetworkPath(iface string) string {
	return filepath.Join("/run/systemd/network/", fmt.Sprintf("70-eks-%s.network", iface))
}

func manageLink(iface, mac string) error {
	ctx := context.TODO()

	// in this first call, we use a client that tolerates and retries 404
	// responses, because we require IMDS eventual consistency.
	deviceIndex, err := getDeviceIndex(ctx, imds.NewClient(imds.New(true)), mac)
	if err != nil {
		return err
	}
	// in this second call, we know that IMDS either works OR the program would
	// have exited, so we dont use a client that tolerates 404s because the
	// 'network-card' property will also NOT exist unless the instance type
	// supports it. In those cases a 404 should translate to a 0-value.
	networkCard, err := getNetworkCard(ctx, imds.NewClient(imds.New(false)), mac)
	if err != nil {
		if isNotFoundErr(err) {
			networkCard = 0
		} else {
			// not good. should never happen.
			panic(err)
		}
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

func getDeviceIndex(ctx context.Context, imdsClient imds.IMDSClient, mac string) (int, error) {
	deviceIndex, err := imdsClient.GetProperty(ctx, imds.DeviceIndex(mac))
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(deviceIndex)
}

func getNetworkCard(ctx context.Context, imdsClient imds.IMDSClient, mac string) (int, error) {
	networkCard, err := imdsClient.GetProperty(ctx, imds.NetworkCard(mac))
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(networkCard)
}

func isNotFoundErr(err error) bool {
	// TODO: implement a more robust check. example data:
	// "operation error ec2imds: GetMetadata, http response error StatusCode: 404, request to EC2 IMDS failed"
	return strings.Contains(err.Error(), "StatusCode: 404")
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
