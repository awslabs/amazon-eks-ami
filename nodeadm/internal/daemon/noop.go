//go:build !linux

package daemon

import "context"

var _ DaemonManager = &noopDaemonManager{}

type noopDaemonManager struct{}

func NewDaemonManager() (DaemonManager, error) {
	return &noopDaemonManager{}, nil
}

func (m *noopDaemonManager) StartDaemon(ctx context.Context, name string) error {
	return nil
}

func (m *noopDaemonManager) StopDaemon(ctx context.Context, name string) error {
	return nil
}

func (m *noopDaemonManager) RestartDaemon(ctx context.Context, name string) error {
	return nil
}

func (m *noopDaemonManager) GetDaemonStatus(ctx context.Context, name string) (DaemonStatus, error) {
	return DaemonStatusUnknown, nil
}

func (m *noopDaemonManager) EnableDaemon(ctx context.Context, name string) error {
	return nil
}

func (m *noopDaemonManager) DisableDaemon(ctx context.Context, name string) error {
	return nil
}

func (m *noopDaemonManager) Reload(ctx context.Context) error {
	return nil
}

func (m *noopDaemonManager) Close() {}
