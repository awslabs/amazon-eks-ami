//go:build linux

package daemon

import (
	"context"
	"fmt"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/coreos/go-systemd/v22/dbus"
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
	if _, err := m.conn.StartUnitContext(context.TODO(), getServiceUnitName(name), ModeReplace, nil); err != nil {
		return err
	}
	return m.waitForStatus(context.TODO(), name, DaemonStatusRunning)
}

func (m *systemdDaemonManager) StopDaemon(name string) error {
	if _, err := m.conn.StopUnitContext(context.TODO(), getServiceUnitName(name), ModeReplace, nil); err != nil {
		return err
	}
	return m.waitForStatus(context.TODO(), name, DaemonStatusStopped)
}

func (m *systemdDaemonManager) RestartDaemon(name string) error {
	if _, err := m.conn.RestartUnitContext(context.TODO(), getServiceUnitName(name), ModeReplace, nil); err != nil {
		return err
	}
	return m.waitForStatus(context.TODO(), name, DaemonStatusRunning)
}

func (m *systemdDaemonManager) GetDaemonStatus(name string) (DaemonStatus, error) {
	unitName := getServiceUnitName(name)
	status, err := m.conn.GetUnitPropertyContext(context.TODO(), unitName, "ActiveState")
	if err != nil {
		return DaemonStatusUnknown, err
	}
	switch status.Value.Value().(string) {
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

func (m *systemdDaemonManager) waitForStatus(ctx context.Context, name string, targetStatus DaemonStatus) error {
	return util.NewRetrier(
		util.WithRetryAlways(),
		util.WithBackoffFixed(250*time.Millisecond),
	).Retry(ctx, func() error {
		status, err := m.GetDaemonStatus(name)
		if err != nil {
			return err
		}
		if status != targetStatus {
			return fmt.Errorf("%s status is not %q", name, targetStatus)
		}
		return nil
	})
}
