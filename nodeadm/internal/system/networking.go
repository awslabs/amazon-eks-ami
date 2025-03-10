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
	//go:embed primary-interface.network.tpl
	primaryInterfaceTemplateData string
	primaryInterfaceTemplate     = template.Must(template.New("primary-interface").Parse(primaryInterfaceTemplateData))
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
	if err := a.ensurePrimaryInterfaceNetworkConfiguration(cfg); err != nil {
		return fmt.Errorf("failed to ensure primary interface network configuration: %w", err)
	}
	//	if err := a.ensureAdditionalInterfaceNetworkConfigurations(cfg); err != nil {
	//		return fmt.Errorf("failed to ensure additional interface network configuration: %w", err)
	//	}
	if err := a.reloadNetworkConfigurations(); err != nil {
		return fmt.Errorf("failed to reload network configurations: %w", err)
	}
	return nil
}

// ensurePrimaryInterfaceNetworkConfiguration will install eks specific network configuration into system.
// NOTE: this is a temporary fix for AL2023, where the `80-ec2.network` setup by amazon-ec2-net-utils will cause systemd.network
// to manage all ENIs on host, and that can potentially result in multiple issues including:
//  1. systemd.network races against vpc-cni to configure secondary enis and might cause routing rules/routes setup by vpc-cni to be flushed resulting in issues with pod networking.
//  2. routes for those secondary ENIs obtained from dhcp will appear in main route table, which is a drift from our AL2 behavior.
//
// To address this issue temporarily, we use drop-ins to alter configuration of `80-ec2.network` after boot to make it match against primary ENI only.
// TODO: there are limitations on current solutions as well, and we should figure long term solution for this:
//  1. the altNames for ENIs(a new feature in AL2023) were setup by amazon-ec2-net-utils via udev rules, but it's disabled by eks.
func (a *networkingAspect) ensurePrimaryInterfaceNetworkConfiguration(cfg *api.NodeConfig) error {
	networkCfgDropInDir := fmt.Sprintf("%s/%s.d", administrationNetworkDir, ec2NetworkConfigurationName)
	eksPrimaryENIOnlyConfPathName := fmt.Sprintf("%s/%s", networkCfgDropInDir, eksPrimaryENIOnlyConfName)
	if exists, err := util.IsFilePathExists(eksPrimaryENIOnlyConfPathName); err != nil {
		return fmt.Errorf("failed to check eks_primary_eni_only network configuration existance: %w", err)
	} else if exists {
		zap.L().Info("eks_primary_eni_only network configuration already exists, skipping configuration")
		return nil
	}

	eksPrimaryENIOnlyConfContent, err := generatePrimaryInterfaceNetworkConfiguration(cfg)
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

type primaryInterfaceTemplateVariables struct {
	PermanentMACAddress string
}

func generatePrimaryInterfaceNetworkConfiguration(cfg *api.NodeConfig) ([]byte, error) {
	primaryENIMac := cfg.Status.Instance.MAC
	templateVars := primaryInterfaceTemplateVariables{
		PermanentMACAddress: primaryENIMac,
	}

	var buf bytes.Buffer
	if err := primaryInterfaceTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// ensureAdditionalInterfaceNetworkConfigurations configures the non-zero card interfaces
// in a way that mimics the default ec2-net-utils behavior on AL2023.
func (a *networkingAspect) ensureAdditionalInterfaceNetworkConfigurations(cfg *api.NodeConfig) error {
	for _, iface := range cfg.Status.Instance.NetworkInterfaces {
		if iface.NetworkCard == 0 {
			continue
		}
		// https://github.com/amazonlinux/amazon-ec2-net-utils/blob/80ce62f654da3cb752be2dfe55279b86d01042e0/udev/99-vpc-policy-routes.rules#L2
		unit := fmt.Sprintf("policy-routes@%s.service", iface.InterfaceId)
		// #nosec G204 Subprocess launched with variable
		cmd := exec.Command("systemctl", "enable", "--now", "--no-block", unit)
		var buf bytes.Buffer
		cmd.Stdout = &buf
		cmd.Stderr = &buf
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to create unit %s for network interface: %+v: %s", unit, iface, buf.String())
		}
		zap.L().Sugar().Infof("configured network interface", zap.String("unit", unit), zap.Reflect("interface", iface))
	}
	return nil
}

func (a *networkingAspect) reloadNetworkConfigurations() error {
	cmd := exec.Command("networkctl", "reload")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
