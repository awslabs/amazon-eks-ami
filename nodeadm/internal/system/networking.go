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
	"time"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
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
)

// EnsureEKSNetworkConfiguration will assert and wait for the OS networking
// stack components required for EKS to be configured and ready.
func EnsureEKSNetworkConfiguration(ctx context.Context, interfaceHints []string) error {
	primaryENIMac, err := imds.DefaultClient().GetProperty(ctx, imds.MAC)
	if err != nil {
		return fmt.Errorf("failed to get MAC from IMDS: %w", err)
	}
	primaryLinkName, err := getLinkNameByMacAddress(primaryENIMac)
	if err != nil {
		return fmt.Errorf("failed to determine the name of primary link: %w", err)
	}
	if err := ensureInterfacesConfigured(ctx, append(interfaceHints, primaryLinkName)); err != nil {
		return fmt.Errorf("failed to ensure primary ENI only configuration: %w", err)
	}
	return nil
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

func ensureInterfacesConfigured(ctx context.Context, interfaceNames []string) error {
	ctx, cancel := context.WithTimeout(ctx, 1*time.Minute)
	defer cancel()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(50 * time.Millisecond):
			zap.L().Info("checking link states...")

			var rawListOutput bytes.Buffer
			var networkctlOutput NetworkctlList
			cmd := exec.CommandContext(ctx, "networkctl", "list", "--json=pretty")
			cmd.Stdout = &rawListOutput
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				return err
			}
			if err := json.Unmarshal(rawListOutput.Bytes(), &networkctlOutput); err != nil {
				return err
			}

			requiredManagedMap := map[string]bool{}
			for _, interfaceName := range interfaceNames {
				requiredManagedMap[interfaceName] = false
			}

			// circuit break to false if we find an interface that is NOT
			// unmanaged but SHOULD be.
			requiredUnmanaged := true

			for _, link := range networkctlOutput.Interfaces {
				if _, required := requiredManagedMap[link.Name]; required {
					if link.AdministrativeState == "configured" {
						zap.L().Info("link configured", zap.String("linkName", link.Name))
						requiredManagedMap[link.Name] = true
					} else {
						zap.L().Info("link not yet configured", zap.String("linkName", link.Name), zap.String("linkState", link.AdministrativeState))
					}
				} else {
					if link.AdministrativeState != "unmanaged" {
						requiredUnmanaged = false
						zap.L().Info("secondary link not yet unmanaged", zap.String("linkName", link.Name), zap.String("linkState", link.AdministrativeState))
					} else {
						zap.L().Info("secondary link unmanaged", zap.String("linkName", link.Name))
					}
				}
			}

			// circuit break to false if we find an interface that is NOT
			// managed but SHOULD be.
			requiredManaged := true
			for _, managed := range requiredManagedMap {
				requiredManaged = requiredManaged && managed
			}
			if requiredManaged && requiredUnmanaged {
				return nil
			}
		}
	}
}
