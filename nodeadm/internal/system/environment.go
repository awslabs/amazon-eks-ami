package system

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	environmentAspectName      = "environment"
	systemdEnvironmentConfPath = "/etc/systemd/system.conf.d/environment.conf"
)

func NewEnvironmentAspect() SystemAspect {
	return &environmentAspect{}
}

type environmentAspect struct{}

func (a *environmentAspect) Name() string {
	return environmentAspectName
}

func (a *environmentAspect) Setup(cfg *api.NodeConfig) error {
	if len(cfg.Spec.Instance.Environment) == 0 {
		zap.L().Info("No environment variables to configure")
		return nil
	}

	return a.configureEnvironment(cfg.Spec.Instance.Environment)
}

// configureEnvironment makes environment variables available system-wide to all processes and services.
func (a *environmentAspect) configureEnvironment(envVars map[string]string) error {
	log := zap.L()

	// Configure systemd system.conf.d for all services
	// Nodeadm will use the lowest precedence directive i.e. DefaultEnvironment= to configure environment
	// Note that EnvironmentFile= and Environment= directives will take precedence over DefaultEnvironment=.
	// Reference: systemd.exec(5) and systemd-system.conf(5) man pages
	// https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Environment
	if err := a.writeSystemdEnvironmentConfig(envVars); err != nil {
		return fmt.Errorf("failed to write systemd environment config: %w", err)
	}

	for key, value := range envVars {
		if err := os.Setenv(key, value); err != nil {
			log.Warn("Failed to set environment variable", zap.String("key", key), zap.Error(err))
		}
		log.Info("Set environment variable", zap.String("key", key), zap.String("value", value))
	}

	return nil
}

func (a *environmentAspect) writeSystemdEnvironmentConfig(envVars map[string]string) error {
	if len(envVars) == 0 {
		return nil
	}

	log := zap.L()
	log.Info("Writing environment variables to systemd system.conf.d", zap.Int("count", len(envVars)))

	content := a.generateSystemdConfig(envVars)

	if err := util.WriteFileWithDir(systemdEnvironmentConfPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write systemd environment config: %w", err)
	}

	log.Info("Reloading systemd configuration")
	if err := exec.Command("systemctl", "daemon-reload").Run(); err != nil {
		return fmt.Errorf("failed to reload systemd configuration: %w", err)
	}

	return nil
}

func (a *environmentAspect) generateSystemdConfig(envVars map[string]string) string {
	var builder strings.Builder
	builder.WriteString("[Manager]\n")

	for key, value := range envVars {
		escapedValue := a.escapeSystemdValue(value)
		builder.WriteString(fmt.Sprintf("DefaultEnvironment=\"%s=%s\"\n", key, escapedValue))
	}

	return builder.String()
}

func (a *environmentAspect) escapeSystemdValue(value string) string {
	// properly escapes special characters in systemd configuration values
	value = strings.ReplaceAll(value, "\\", "\\\\")
	value = strings.ReplaceAll(value, "\"", "\\\"")
	return value
}
