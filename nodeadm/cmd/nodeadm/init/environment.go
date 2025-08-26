package init

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

const (
	systemdEnvironmentConfPath = "/etc/systemd/system.conf.d/environment.conf"
)

// making environment variables available system-wide to all processes and services.
func handleSystemEnvironmentVariables(log *zap.Logger, instanceOpts api.InstanceOptions) error {
	if len(instanceOpts.Environment) == 0 {
		log.Info("No environment variables to configure")
		return nil
	}

	// Configure systemd system.conf.d for all services
	// Nodeadm will use the lowest precedence directive i.e. DefaultEnvironment= to configure environment
	// Note that EnvironmentFile= and Environment= directives will take precedence over DefaultEnvironment=.
	// Reference: systemd.exec(5) and systemd-system.conf(5) man pages
	// https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Environment
	if err := writeSystemdEnvironmentConfig(log, instanceOpts.Environment); err != nil {
		return fmt.Errorf("failed to write systemd environment config: %w", err)
	}

	for key, value := range instanceOpts.Environment {
		if err := os.Setenv(key, value); err != nil {
			log.Warn("Failed to set environment variable", zap.String("key", key), zap.Error(err))
		}
		log.Info("Set environment variable", zap.String("key", key), zap.String("value", value))
	}

	return nil
}

func writeSystemdEnvironmentConfig(log *zap.Logger, envVars map[string]string) error {
	if len(envVars) == 0 {
		return nil
	}

	log.Info("Writing environment variables to systemd system.conf.d", zap.Int("count", len(envVars)))

	if err := os.MkdirAll(filepath.Dir(systemdEnvironmentConfPath), 0750); err != nil {
		return fmt.Errorf("failed to create systemd config directory: %w", err)
	}

	file, err := os.Create(systemdEnvironmentConfPath)
	if err != nil {
		return fmt.Errorf("failed to create systemd config file: %w", err)
	}
	defer file.Close()

	if err := file.Chmod(0644); err != nil {
		return fmt.Errorf("failed to set systemd config file permissions: %w", err)
	}

	if _, err := fmt.Fprintln(file, "[Manager]"); err != nil {
		return fmt.Errorf("failed to write systemd config header: %w", err)
	}

	for key, value := range envVars {
		if _, err := fmt.Fprintf(file, "DefaultEnvironment=\"%s=%s\"\n", key, value); err != nil {
			return fmt.Errorf("failed to write environment variable %s: %w", key, err)
		}
	}

	log.Info("Reloading systemd configuration")
	if err := exec.Command("systemctl", "daemon-reload").Run(); err != nil {
		return fmt.Errorf("failed to reload systemd configuration: %w", err)
	}

	return nil
}
