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
	managerSystemd = "io.systemd.Network"

	// NOTE: other manager names have no functional value, they only need to be
	// differentiated from the managerSystemd name.

	managerCNI = "cni"
)

const (
	// drop-in for the amazon-ec2-net-util default ENI config
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network
	ec2NetworkDropinPath = "/run/systemd/network/80-ec2.network.d"
)

func (c *netManager) removeAction(_ context.Context, log *zap.Logger) error {
	configPath := eksNetworkPath(c.iface)
	log.Info("removing interface network config", zap.String("configPath", configPath))
	return os.RemoveAll(configPath)
}

func (c *netManager) addAction(ctx context.Context, log *zap.Logger) error {
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
		if err := manageLink(ctx, c.iface, mac); err != nil {
			return err
		}

		primaryMac, err := imds.DefaultClient().GetProperty(ctx, imds.MAC)
		if err != nil {
			return err
		}
		// some default networking is required to obtain interfaces that can
		// communicate with IMDS. once we can reach IMDS and explicitly
		// configure the primary interface, we disable default networking so
		// that future links do not become managed unless we intend to do so.
		// this condition also guarantees that we only attempt to create this
		// drop-in a single time.
		//
		// TODO: handle race condition with other interfaces attached at boot?
		if primaryMac == mac {
			configPath := filepath.Join(ec2NetworkDropinPath, "10-eks-disable.conf")
			log.Info("disabling default ec2 network", zap.String("configPath", configPath))
			if err := util.WriteFileWithDir(configPath, []byte("[Match]\nName=none"), 0644); err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *netManager) determineManager() (string, error) {
	// TODO: for now we return 'io.systemd.Network' for any interface present at
	// boot time; before the CNI is able to start managing and dynamically
	// attaching additional interfaces to the instance. in the future we should
	// communicate with another service/broker to get info on whether a given
	// interface should be managed or not.

	// this code checks whether cloud-init has finished booting the node, which
	// is indicative of most user-influenced actions being completed. it's not
	// perfect but it works under the basic assumptions.
	// IMPORTANT: you should not be re-running this after initial boot, because
	// it will think any interface is managed by the CNI.
	const cloudInitBootResultPath = "/run/cloud-init/result.json"
	if _, err := os.Stat(cloudInitBootResultPath); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return managerSystemd, nil
		}
		return "", err
	}
	return managerCNI, nil
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

func manageLink(ctx context.Context, iface, mac string) error {
	// in this first call, we use a client that tolerates and retries 404
	// responses, because we require IMDS eventual consistency.
	deviceIndex, err := getDeviceIndex(ctx, imds.NewClient(imds.New(true)), mac)
	if err != nil {
		return err
	}
	// in this second call, we know that IMDS either works OR the program would
	// have exited, so we dont use a client that tolerates 404s. The interface
	// 'network-card' property in IMDS may or may not exist depending on the
	// whether the instance type is multi-nic enabled, and in cases where it is
	// not the 404 should be translated to the 0'th index.
	networkCard, err := getNetworkCard(ctx, imds.NewClient(imds.New(false)), mac)
	if err != nil {
		if isNotFoundErr(err) {
			networkCard = 0
		} else {
			// not good. should never happen.
			panic(err)
		}
	}

	const (
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L39
		metricBase = 512
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L32
		ruleBase = 10000
	)

	var buf bytes.Buffer
	if err := managedTemplate.Execute(&buf, struct {
		MAC     string
		Metric  int
		TableID int
	}{
		MAC: mac,
		// setup route metics. this provides priority on good interfaces over
		// ones that could potentially delay startup.
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L348-L366
		Metric: metricBase + 100*networkCard + deviceIndex,
		// setup table id for expected routes established by amazon-ec2-net-utils
		// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L349
		TableID: ruleBase + 100*networkCard + deviceIndex,
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

func eksNetworkPath(iface string) string {
	return filepath.Join("/run/systemd/network/", fmt.Sprintf("70-eks-%s.network", iface))
}

func isNotFoundErr(err error) bool {
	// TODO: implement a more robust check. example data:
	// "operation error ec2imds: GetMetadata, http response error StatusCode: 404, request to EC2 IMDS failed"
	return strings.Contains(err.Error(), "StatusCode: 404")
}
