package daemon

import "context"

type DaemonStatus string

const (
	DaemonStatusRunning DaemonStatus = "running"
	DaemonStatusStopped DaemonStatus = "stopped"
	DaemonStatusUnknown DaemonStatus = "unknown"
)

type DaemonManager interface {
	// StartDaemon starts the daemon with the given name, blocking until the
	// daemon has finished starting.
	// If the daemon is already running, this is a no-op.
	StartDaemon(ctx context.Context, name string) error
	// StopDaemon stops the daemon with the given name, blocking until the
	// daemon has finished stopping.
	// If the daemon is not running, this is a no-op.
	StopDaemon(ctx context.Context, name string) error
	// RestartDaemon restarts the daemon with the given name, blocking until the
	// daemon has stopped and finished starting again.
	// If the daemon is not running, it will be started.
	RestartDaemon(ctx context.Context, name string) error
	// GetDaemonStatus returns the status of the daemon with the given name.
	//
	// Note that the returned status is only a point-in-time observation, and the
	// daemon may change state immediately afterwards. Prefer making operations
	// that depend on a daemon retryable over gating them on this status.
	GetDaemonStatus(ctx context.Context, name string) (DaemonStatus, error)
	// EnableDaemon enables the daemon with the given name.
	// If the daemon is already enabled, this is a no-op.
	EnableDaemon(ctx context.Context, name string) error
	// DisableDaemon disables the daemon with the given name.
	// If the daemon is not enabled, this is a no-op.
	DisableDaemon(ctx context.Context, name string) error
	// Reload instructs the daemon manager to scan for and reload unit files,
	// picking up any unit file changes made since it last did so. This is the
	// equivalent of `systemctl daemon-reload`.
	Reload(ctx context.Context) error
	// Close cleans up any underlying resources used by the daemon manager.
	Close()
}
