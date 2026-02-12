package udev

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
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

// ensureDropinCompat creates a symlink so that drop-in files written by
// amazon-ec2-net-utils (into 70-{iface}.network.d/) are found by
// systemd-networkd when it reads the EKS-managed network file
// (70-eks-{iface}.network). Without this, secondary IP aliases created by
// ec2-net-utils are silently ignored.
// see: https://github.com/awslabs/amazon-eks-ami/issues/2623
func ensureDropinCompat(iface string) error {
	unitdir := "/run/systemd/network"
	ec2netDir := filepath.Join(unitdir, fmt.Sprintf("70-%s.network.d", iface))
	eksDir := filepath.Join(unitdir, fmt.Sprintf("70-eks-%s.network.d", iface))
	if err := os.MkdirAll(ec2netDir, 0755); err != nil {
		return fmt.Errorf("failed to create ec2-net-utils drop-in dir: %w", err)
	}
	// Remove existing symlink or directory if present to ensure idempotency
	os.Remove(eksDir)
	return os.Symlink(ec2netDir, eksDir)
}

func disableDefaultEc2Networking() error {
	// drop-in for the amazon-ec2-net-util default ENI config
	// see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network
	const ec2NetworkDropinPath = "/run/systemd/network/80-ec2.network.d"

	dropinConfigPath := filepath.Join(ec2NetworkDropinPath, "10-eks-disable.conf")

	// force the default network to match no real interfaces.
	return util.WriteFileWithDir(dropinConfigPath, []byte("[Match]\nName=none"), 0644)
}
