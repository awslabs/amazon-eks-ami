package system

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

type NetworkctlInterface struct {
	Name                string `json:"Name"`
	AdministrativeState string `json:"AdministrativeState"`
}

type NetworkctlList struct {
	Interfaces []NetworkctlInterface `json:"Interfaces"`
}

const (
	networkDeviceDir   = "/sys/class/net"
	macAddressFileName = "address"
	// the ephemeral networkd config directory, reset on reboot
	administrationNetworkDir = "/run/systemd/network"
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
)

// ensureEKSNetworkConfiguration will install eks specific network configuration into system.
// NOTE: this is a temporary fix for AL2023, where the `80-ec2.network` setup by amazon-ec2-net-utils will cause systemd.network
// to manage all ENIs on host, and that can potentially result in multiple issues including:
//  1. systemd.network races against vpc-cni to configure secondary enis and might cause routing rules/routes setup by vpc-cni to be flushed resulting in issues with pod networking.
//  2. routes for those secondary ENIs obtained from dhcp will appear in main route table, which is a drift from our AL2 behavior.
//
// To address this issue temporarily, we use drop-ins to alter configuration of `80-ec2.network` after boot to make it match against primary ENI only.
// TODO: there are limitations on current solutions as well, and we should figure long term solution for this:
//  1. the altNames for ENIs(a new feature in AL2023) were setup by amazon-ec2-net-utils via udev rules, but it's disabled by eks.
func EnsureEKSNetworkConfiguration() error {
	primaryENIMac, err := imds.GetProperty(context.TODO(), "mac")
	if err != nil {
		return fmt.Errorf("failed to get MAC from IMDS: %w", err)
	}
	networkCfgDropInDir := fmt.Sprintf("%s/%s.d", administrationNetworkDir, ec2NetworkConfigurationName)
	eksPrimaryENIOnlyConfPathName := fmt.Sprintf("%s/%s", networkCfgDropInDir, eksPrimaryENIOnlyConfName)
	if exists, err := util.IsFilePathExists(eksPrimaryENIOnlyConfPathName); err != nil {
		return fmt.Errorf("failed to check eks_primary_eni_only network configuration existance: %w", err)
	} else if exists {
		zap.L().Info("eks_primary_eni_only network configuration already exists, skipping configuration")
		return nil
	}
	eksPrimaryENIOnlyConfContent, err := generateEKSPrimaryENIOnlyConfiguration(primaryENIMac)
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
	if err := reloadNetworkConfigurations(); err != nil {
		return fmt.Errorf("failed to reload network configurations: %w", err)
	}
	primaryLinkName, err := getLinkNameByMacAddress(primaryENIMac)
	if err != nil {
		return fmt.Errorf("failed to determine the name of primary link: %w", err)
	}
	if err := ensurePrimaryOnlyConfiguration(primaryLinkName); err != nil {
		return fmt.Errorf("failed to ensure primary ENI only configuration: %w", err)
	}
	return nil
}

// eksPrimaryENIOnlyTemplateVars holds the variables for eksPrimaryENIOnlyConfTemplate
type eksPrimaryENIOnlyTemplateVars struct {
	PermanentMACAddress string
}

// generateEKSPrimaryENIOnlyConfiguration generates the eks primary eni only network configuration.
func generateEKSPrimaryENIOnlyConfiguration(primaryENIMac string) ([]byte, error) {
	templateVars := eksPrimaryENIOnlyTemplateVars{
		PermanentMACAddress: primaryENIMac,
	}

	var buf bytes.Buffer
	if err := eksPrimaryENIOnlyConfTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func reloadNetworkConfigurations() error {
	cmd := exec.Command("networkctl", "reload")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func getLinkNameByMacAddress(macAddress string) (string, error) {
	entries, err := os.ReadDir(networkDeviceDir)
	if err != nil {
		return "", err
	}
	for _, entry := range entries {
		linkName := entry.Name()
		interfaceDir := filepath.Join(networkDeviceDir, linkName)
		currentAddressesFile := filepath.Join(interfaceDir, macAddressFileName)
		// #nosec G304 // variable read from target directory
		currentAddressBytes, err := os.ReadFile(currentAddressesFile)
		if err != nil {
			zap.L().Info("skipping interface because of an error reading address file", zap.String("linkName", linkName), zap.Error(err))
			continue
		}
		currentAddress := strings.TrimSpace(string(currentAddressBytes))
		if currentAddress != macAddress {
			continue
		}
		return linkName, nil
	}
	return "", fmt.Errorf("could not find interface with MAC address %q", macAddress)
}

func ensurePrimaryOnlyConfiguration(primaryLinkName string) error {
	ctx, cancel := context.WithTimeout(context.TODO(), 1*time.Minute)
	defer cancel()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(50 * time.Millisecond):
			var primaryConfigured bool
			var rawListOutput bytes.Buffer
			var networkctlOutput NetworkctlList
			secondariesUnmanaged := true // assume no secondaries unless we find one
			zap.L().Info("checking link states...")
			cmd := exec.CommandContext(ctx, "networkctl", "list", "--json=pretty")
			cmd.Stdout = &rawListOutput
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				return err
			}
			if err := json.Unmarshal(rawListOutput.Bytes(), &networkctlOutput); err != nil {
				return err
			}
			for _, link := range networkctlOutput.Interfaces {
				if link.Name == primaryLinkName {
					if link.AdministrativeState == "configured" {
						zap.L().Info("primary link configured", zap.String("linkName", link.Name))
						primaryConfigured = true
					} else {
						zap.L().Info("primary link not yet configured", zap.String("linkName", link.Name), zap.String("linkState", link.AdministrativeState))
					}
				} else {
					if link.AdministrativeState != "unmanaged" {
						secondariesUnmanaged = false
						zap.L().Info("secondary link not yet unmanaged", zap.String("linkName", link.Name), zap.String("linkState", link.AdministrativeState))
					} else {
						zap.L().Info("secondary link unmanaged", zap.String("linkName", link.Name))
					}
				}
			}
			if primaryConfigured && secondariesUnmanaged {
				return nil
			}
		}
	}
}
