//go:build linux

package daemon

import (
	"context"
	"fmt"
	"time"

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

	// jobResultDone is the systemd job result indicating that a job ran to
	// completion successfully. The other possible results are: canceled,
	// timeout, failed, dependency, and skipped.
	jobResultDone = "done"

	// defaultJobTimeout bounds how long we will wait for a systemd job to
	// complete when the caller's context carries no deadline of its own.
	// systemd enforces its own per-unit job timeouts and will report a job
	// result of "timeout" when they are exceeded, so this is only a backstop
	// against never hearing back from systemd at all.
	defaultJobTimeout = 5 * time.Minute
)

// unitJobFunc enqueues a systemd job for a unit, matching the signature of the
// go-systemd Conn methods that operate on units, e.g. StartUnitContext.
type unitJobFunc func(ctx context.Context, name string, mode string, ch chan<- string) (int, error)

func NewDaemonManager() (DaemonManager, error) {
	conn, err := dbus.NewWithContext(context.Background())
	if err != nil {
		return nil, err
	}
	return &systemdDaemonManager{
		conn: conn,
	}, nil
}

func (m *systemdDaemonManager) StartDaemon(ctx context.Context, name string) error {
	return m.runUnitJob(ctx, name, "start", m.conn.StartUnitContext)
}

func (m *systemdDaemonManager) StopDaemon(ctx context.Context, name string) error {
	return m.runUnitJob(ctx, name, "stop", m.conn.StopUnitContext)
}

func (m *systemdDaemonManager) RestartDaemon(ctx context.Context, name string) error {
	return m.runUnitJob(ctx, name, "restart", m.conn.RestartUnitContext)
}

// runUnitJob enqueues a systemd job for the given daemon and blocks until
// systemd reports that the job has completed.
//
// The Start/Stop/RestartUnit methods reply as soon as the job has been
// *enqueued*, not once it has run. PID 1 sends the reply from its D-Bus handler
// while the job is still sitting in the run queue, and the run queue is
// dispatched at a lower event loop priority than incoming IPC. A caller that
// reads the unit's ActiveState immediately after the call returns is therefore
// likely to observe the state from before the job ran, e.g. the still-running
// process that a restart is about to stop.
//
// Waiting on the job's completion signal avoids that entirely: systemd emits
// JobRemoved only once the job is finished, which for a restart is after the
// unit has been stopped and has become active again. For a Type=notify unit,
// "active" means the service has sent READY=1.
func (m *systemdDaemonManager) runUnitJob(ctx context.Context, name string, verb string, enqueue unitJobFunc) error {
	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, defaultJobTimeout)
		defer cancel()
	}

	unitName := getServiceUnitName(name)

	// this channel must be buffered: the connection cannot process further jobs
	// until the completion result has been written to it, and we abandon it
	// without reading if we stop waiting below.
	resultCh := make(chan string, 1)

	// note that go-systemd registers resultCh for the job's completion signal
	// while holding the lock its signal dispatcher needs, so the result cannot
	// be missed even if the job completes before this call returns.
	if _, err := enqueue(ctx, unitName, ModeReplace, resultCh); err != nil {
		return fmt.Errorf("enqueuing %s job for %s: %w", verb, unitName, err)
	}

	select {
	case result := <-resultCh:
		if result != jobResultDone {
			return fmt.Errorf("%s job for %s finished with result %q", verb, unitName, result)
		}
		return nil
	case <-ctx.Done():
		return fmt.Errorf("waiting for %s job for %s to complete: %w", verb, unitName, ctx.Err())
	}
}

func (m *systemdDaemonManager) GetDaemonStatus(ctx context.Context, name string) (DaemonStatus, error) {
	unitName := getServiceUnitName(name)
	status, err := m.conn.GetUnitPropertyContext(ctx, unitName, "ActiveState")
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

func (m *systemdDaemonManager) EnableDaemon(ctx context.Context, name string) error {
	unitName := getServiceUnitName(name)
	_, changes, err := m.conn.EnableUnitFilesContext(ctx, []string{unitName}, false, false)
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

func (m *systemdDaemonManager) DisableDaemon(ctx context.Context, name string) error {
	unitName := getServiceUnitName(name)
	changes, err := m.conn.DisableUnitFilesContext(ctx, []string{unitName}, false)
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

// Reload instructs systemd to scan for and reload unit files, e.g. to pick up a
// drop-in written by a daemon's Configure step. This is the D-Bus equivalent of
// `systemctl daemon-reload`.
func (m *systemdDaemonManager) Reload(ctx context.Context) error {
	return m.conn.ReloadContext(ctx)
}

func (m *systemdDaemonManager) Close() {
	m.conn.Close()
}

func getServiceUnitName(name string) string {
	return fmt.Sprintf("%s.service", name)
}
