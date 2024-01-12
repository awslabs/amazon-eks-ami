//go:build linux

package daemon

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"path"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/coreos/go-systemd/dbus"
)

var _ DaemonManager = &systemdDaemonManager{}

type systemdDaemonManager struct {
	conn *dbus.Conn
}

const (
	ModeReplace = "replace"
	TypeSymlink = "symlink"
	TypeUnlink  = "unlink"
)

func NewDaemonManager() (DaemonManager, error) {
	conn, err := dbus.NewWithContext(context.Background())
	if err != nil {
		return nil, err
	}
	return &systemdDaemonManager{
		conn: conn,
	}, nil
}

func (m *systemdDaemonManager) StartDaemon(name string) error {
	unitName := getServiceUnitName(name)
	_, err := m.conn.StartUnitContext(context.TODO(), unitName, ModeReplace, nil)
	return err
}

func (m *systemdDaemonManager) StopDaemon(name string) error {
	unitName := getServiceUnitName(name)
	_, err := m.conn.StopUnitContext(context.TODO(), unitName, ModeReplace, nil)
	return err
}

func (m *systemdDaemonManager) RestartDaemon(name string) error {
	unitName := getServiceUnitName(name)
	_, err := m.conn.RestartUnitContext(context.TODO(), unitName, ModeReplace, nil)
	return err
}

func (m *systemdDaemonManager) GetDaemonStatus(name string) (DaemonStatus, error) {
	unitName := getServiceUnitName(name)
	status, err := m.conn.GetUnitPropertyContext(context.TODO(), unitName, "ActiveState")
	if err != nil {
		return DaemonStatusUnknown, err
	}
	switch status.Value.String() {
	case "active":
		return DaemonStatusRunning, nil
	case "inactive":
		return DaemonStatusStopped, nil
	default:
		return DaemonStatusUnknown, nil
	}
}

func (m *systemdDaemonManager) EnableDaemon(name string) error {
	unitName := getServiceUnitName(name)
	_, changes, err := m.conn.EnableUnitFilesContext(context.TODO(), []string{unitName}, false, false)
	if err != nil {
		return err
	}
	if len(changes) != 1 {
		return fmt.Errorf("unexpected number of unit file changes: %d", len(changes))
	}
	if changes[0].Type != TypeSymlink {
		return fmt.Errorf("unexpected unit file change type: %s", changes[0].Type)
	}
	return nil
}

func (m *systemdDaemonManager) DisableDaemon(name string) error {
	unitName := getServiceUnitName(name)
	changes, err := m.conn.DisableUnitFilesContext(context.TODO(), []string{unitName}, false)
	if err != nil {
		return err
	}
	if len(changes) != 1 {
		return fmt.Errorf("unexpected number of unit file changes: %d", len(changes))
	}
	if changes[0].Type != TypeUnlink {
		return fmt.Errorf("unexpected unit file change type: %s", changes[0].Type)
	}
	return nil
}

func (m *systemdDaemonManager) Close() {
	m.conn.Close()
}

func getServiceUnitName(name string) string {
	return fmt.Sprintf("%s.service", name)
}

func getServiceUnitDropInDir(name string) string {
	return fmt.Sprintf("%s.d", getServiceUnitName(name))
}

// Constructs systemd drop-in configurations related to startup dependencies and requirements
func ConfigureDependencies(daemonName string, requiredDaemonNames ...string) error {
	serviceNames := make([]string, len(requiredDaemonNames))
	for i, daemon := range requiredDaemonNames {
		serviceNames[i] = getServiceUnitName(daemon)
	}
	serviceList := strings.Join(serviceNames, " ")
	fileContent := util.Dedent(fmt.Sprintf(`
		[Unit]
		After=%s
		Requires=%s`,
		serviceList, serviceList))
	return WriteSystemdServiceUnitDropIn(daemonName, "00-dependencies.conf", fileContent, 0644)
}

const servicesRoot = "/etc/systemd/system"

func WriteSystemdServiceUnitDropIn(serviceName, fileName, fileContent string, filePerms fs.FileMode) error {
	dropInPath := path.Join(servicesRoot, getServiceUnitDropInDir(serviceName), fileName)
	if err := os.MkdirAll(path.Dir(dropInPath), filePerms); err != nil {
		return err
	}
	return os.WriteFile(dropInPath, []byte(fileContent), filePerms)
}

func WriteSystemdServiceUnit(serviceName, unitContent string, filePerms fs.FileMode) error {
	serviceUnitPath := path.Join(servicesRoot, getServiceUnitName(serviceName))
	return os.WriteFile(serviceUnitPath, []byte(unitContent), filePerms)
}
