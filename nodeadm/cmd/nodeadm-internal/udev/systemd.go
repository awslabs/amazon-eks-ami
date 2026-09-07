package udev

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

var (
	//go:embed eks-managed.network.tpl
	managedNetworkTemplateData string
	managedNetworkTemplate     = template.Must(template.New("eks-managed").Parse(managedNetworkTemplateData))
)

type networkTemplateVars struct {
	MAC         string
	Metric      int
	TableID     int
	InterfaceIP string
}

func renderNetworkTemplate(templateVars networkTemplateVars) ([]byte, error) {
	var buf bytes.Buffer
	if err := managedNetworkTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func eksNetworkPath(iface string) string {
	return filepath.Join("/run/systemd/network/", fmt.Sprintf("70-eks-%s.network", iface))
}

// Remove only nodeadm's generated file when its named interface now has a
// different identity. No user .network files or drop-ins are changed.
func removeStaleNetworkConfig(configPath, mac string) error {
	data, err := os.ReadFile(configPath)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(data), "\n") {
		if value, found := strings.CutPrefix(strings.TrimSpace(line), "PermanentMACAddress="); found {
			if value == mac {
				return nil
			}
			return os.Remove(configPath)
		}
	}
	return fmt.Errorf("network configuration %s has no permanent MAC; refusing to replace it", configPath)
}

func disableDefaultEc2Networking() error {
	// drop-in for the amazon-ec2-net-util default ENI config
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network
	const ec2NetworkDropinPath = "/run/systemd/network/80-ec2.network.d"

	dropinConfigPath := filepath.Join(ec2NetworkDropinPath, "10-eks-disable.conf")

	// force the default network to match no real interfaces.
	return util.WriteFileWithDir(dropinConfigPath, []byte("[Match]\nName=none"), 0644)
}
