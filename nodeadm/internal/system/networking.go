package system

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const (
	networkingAspectName = "networking"
	// The local administration network directory for systemd.network
	administrationNetworkDir = "/etc/systemd/network"
	// the name of ec2 network configuration setup by amazon-ec2-net-utils:
	// https://github.com/amazonlinux/amazon-ec2-net-utils/blob/c6626fb5cd094bbfeb62c456fe088011dbab3f95/systemd/network/80-ec2.network
	ec2NetworkConfigurationName = "80-ec2.network"
	eksPrimaryENIOnlyConfName   = "10-eks_primary_eni_only.conf"
	networkConfDropInDirPerms   = 0755
	networkConfFilePerms        = 0644
)

var (
	//go:embed _assets/10-eks_primary_eni_only.conf.template
	eksPrimaryENIOnlyConfTemplateData string
	eksPrimaryENIOnlyConfTemplate     = template.Must(template.New(eksPrimaryENIOnlyConfName).Parse(eksPrimaryENIOnlyConfTemplateData))

	//go:embed _assets/interface.network.template
	eksAdditionalENINetworkFileTemplate string
)

// NewNetworkingAspect constructs new networkingAspect.
func NewNetworkingAspect() *networkingAspect {
	return &networkingAspect{}
}

var _ SystemAspect = &networkingAspect{}

// networkingAspect setups eks-specific networking configurations.
type networkingAspect struct{}

// Name returns the name of this aspect.
func (a *networkingAspect) Name() string {
	return networkingAspectName
}

// Setup executes the logic of this aspect.
func (a *networkingAspect) Setup(cfg *api.NodeConfig) error {
	if err := a.ensureEKSNetworkConfiguration(cfg); err != nil {
		return fmt.Errorf("failed to ensure eks network configuration: %w", err)
	}
	if err := a.ensureMulticardNetworkConfiguration(cfg); err != nil {
		return fmt.Errorf("failed to ensure multicard network configuration: %w", err)
	}
	if err := a.reloadNetworkConfigurations(); err != nil {
		return fmt.Errorf("failed to reload network configurations: %w", err)
	}
	return nil
}

// ensureEKSNetworkConfiguration will install eks specific network configuration into system.
// NOTE: this is a temporary fix for AL2023, where the `80-ec2.network` setup by amazon-ec2-net-utils will cause systemd.network
// to manage all ENIs on host, and that can potentially result in multiple issues including:
//  1. systemd.network races against vpc-cni to configure secondary enis and might cause routing rules/routes setup by vpc-cni to be flushed resulting in issues with pod networking.
//  2. routes for those secondary ENIs obtained from dhcp will appear in main route table, which is a drift from our AL2 behavior.
//
// To address this issue temporarily, we use drop-ins to alter configuration of `80-ec2.network` after boot to make it match against primary ENI only.
// TODO: there are limitations on current solutions as well, and we should figure long term solution for this:
//  1. the altNames for ENIs(a new feature in AL2023) were setup by amazon-ec2-net-utils via udev rules, but it's disabled by eks.
func (a *networkingAspect) ensureEKSNetworkConfiguration(cfg *api.NodeConfig) error {
	networkCfgDropInDir := fmt.Sprintf("%s/%s.d", administrationNetworkDir, ec2NetworkConfigurationName)
	eksPrimaryENIOnlyConfPathName := fmt.Sprintf("%s/%s", networkCfgDropInDir, eksPrimaryENIOnlyConfName)
	if exists, err := util.IsFilePathExists(eksPrimaryENIOnlyConfPathName); err != nil {
		return fmt.Errorf("failed to check eks_primary_eni_only network configuration existance: %w", err)
	} else if exists {
		zap.L().Info("eks_primary_eni_only network configuration already exists, skipping configuration")
		return nil
	}

	eksPrimaryENIOnlyConfContent, err := a.generateEKSPrimaryENIOnlyConfiguration(cfg)
	if err != nil {
		return fmt.Errorf("failed to generate eks_primary_eni_only network configuration: %w", err)
	}
	zap.L().Info("writing eks_primary_eni_only network configuration")
	if err := os.MkdirAll(networkCfgDropInDir, networkConfDropInDirPerms); err != nil {
		return fmt.Errorf("failed to create network configuration drop-in directory %s: %w", networkCfgDropInDir, err)
	}
	if err := os.WriteFile(eksPrimaryENIOnlyConfPathName, eksPrimaryENIOnlyConfContent, networkConfFilePerms); err != nil {
		return fmt.Errorf("failed to write eks_primary_eni_only network configuration: %w", err)
	}
	return nil
}

// ensureMulticardNetworkConfiguration configures the non-zero card interfaces in a way that mimics the
// default AL2023 configuration. Non-zero card interfaces are not managed by vpc-cni and we're creating
// systemd-networkd .network files for each interface.
func (a *networkingAspect) ensureMulticardNetworkConfiguration(cfg *api.NodeConfig) error {
	routeTableId := 10101
	routeTableMetric := 613

	for _, card := range cfg.Status.Instance.NetworkCards {
		if card.CardIndex == 0 {
			continue
		}

		networkInterfaceConfName := fmt.Sprintf("70-%s.network", card.InterfaceId)
		networkInterfaceConfPathName := fmt.Sprintf("%s/%s", administrationNetworkDir, networkInterfaceConfName)

		if exists, err := util.IsFilePathExists(networkInterfaceConfPathName); err != nil {
			return fmt.Errorf("failed to check configuration existance for %s: %w", networkInterfaceConfName, err)
		} else if exists {
			zap.L().Sugar().Infof("%s already exists, skipping configuration", networkInterfaceConfName)
			continue
		}

		templateVars := networkInterfaceTemplateVars{
			PermanentMACAddress: card.MAC,
			IpV4Address:         card.IpV4Address,
			IpV4Subnet:          card.IpV4Subnet,
			IpV6Address:         card.IpV6Address,
			IpV6Subnet:          card.IpV6Subnet,
			RouteTableId:        int16(routeTableId),
			RouteTableMetric:    int16(routeTableMetric),
		}
		routeTableId += 100
		routeTableMetric += 100

		interfaceConfigContent, err := a.generateNetworkConfigFile(networkInterfaceConfName, templateVars)
		if err != nil {
			return fmt.Errorf("failed to generate %s configuration: %w", networkInterfaceConfName, err)
		}

		if err := os.WriteFile(networkInterfaceConfPathName, interfaceConfigContent, networkConfFilePerms); err != nil {
			return fmt.Errorf("failed to write %s configuration: %w", networkInterfaceConfName, err)
		}
		zap.L().Sugar().Infof("Multicard instance found, configuring card with index: %d, network file: %s", card.CardIndex, networkInterfaceConfPathName)
	}
	return nil
}

func (a *networkingAspect) generateNetworkConfigFile(interfaceConfName string, templateVars networkInterfaceTemplateVars) ([]byte, error) {
	networkInterfaceConfTemplate := template.Must(template.New(interfaceConfName).Parse(eksAdditionalENINetworkFileTemplate))
	var buf bytes.Buffer
	if err := networkInterfaceConfTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil

}

// eksPrimaryENIOnlyTemplateVars holds the variables for eksPrimaryENIOnlyConfTemplate
type eksPrimaryENIOnlyTemplateVars struct {
	PermanentMACAddress string
}

// networkInterfaceTemplateVars holds the variables for networkInterfaceConfTemplate
type networkInterfaceTemplateVars struct {
	PermanentMACAddress string
	IpV4Address         string
	IpV4Subnet          string
	IpV6Address         string
	IpV6Subnet          string
	RouteTableId        int16
	RouteTableMetric    int16
}

// generateEKSPrimaryENIOnlyConfiguration generates the eks primary eni only network configuration.
func (a *networkingAspect) generateEKSPrimaryENIOnlyConfiguration(cfg *api.NodeConfig) ([]byte, error) {
	primaryENIMac := cfg.Status.Instance.MAC
	templateVars := eksPrimaryENIOnlyTemplateVars{
		PermanentMACAddress: primaryENIMac,
	}

	var buf bytes.Buffer
	if err := eksPrimaryENIOnlyConfTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (a *networkingAspect) reloadNetworkConfigurations() error {
	cmd := exec.Command("networkctl", "reload")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
