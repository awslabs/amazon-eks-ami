package system

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	environmentAspectName       = "environment"
	systemdEnvironmentConfPath  = "/etc/systemd/system.conf.d/environment.conf"
	kubeletServiceDropinPath    = "/etc/systemd/system/kubelet.service.d/environment.conf"
	containerdServiceDropinPath = "/etc/systemd/system/containerd.service.d/environment.conf"
)

const systemdConfigTemplate = `[Manager]
{{range $key, $value := .}}DefaultEnvironment="{{$key}}={{escape $value}}"
{{end}}`

const serviceDropinConfigTemplate = `[Service]
{{range $key, $value := .}}Environment="{{$key}}={{escape $value}}"
{{end}}`

var templateFuncs = template.FuncMap{
	"escape": escapeSystemdValue,
}

func NewEnvironmentAspect() SystemAspect {
	return &environmentAspect{}
}

type environmentAspect struct{}

func (a *environmentAspect) Name() string {
	return environmentAspectName
}

func (a *environmentAspect) Setup(cfg *api.NodeConfig) error {
	envOpts := cfg.Spec.Instance.Environment

	// Check if any environment configuration exists. If nothing to configure, don't invoke systemctl daemon-reload
	if len(envOpts.Default) == 0 && len(envOpts.SystemdKubelet) == 0 && len(envOpts.SystemdContainerd) == 0 {
		zap.L().Info("No environment variables to configure")
		return nil
	}

	return a.configureEnvironment(envOpts)
}

// configureEnvironment makes environment variables available system-wide and to specific services.
func (a *environmentAspect) configureEnvironment(envOpts api.EnvironmentOptions) error {
	// Configure systemd system.conf.d for all services
	// Nodeadm will use the lowest precedence directive i.e. DefaultEnvironment= to configure environment
	// Note that EnvironmentFile= and Environment= directives will take precedence over DefaultEnvironment=.
	// Reference: systemd.exec(5) and systemd-system.conf(5) man pages
	// https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Environment
	if len(envOpts.Default) > 0 {
		if err := a.writeSystemdEnvironmentConfig(envOpts.Default); err != nil {
			return fmt.Errorf("failed to write systemd environment config: %w", err)
		}

		for key, value := range envOpts.Default {
			if err := os.Setenv(key, value); err != nil {
				zap.L().Warn("Failed to set environment variable", zap.String("key", key), zap.Error(err))
				continue
			}
			zap.L().Info("Set default environment variable", zap.String("key", key), zap.String("value", value))
		}
	}

	// Configure kubelet-specific environment variables
	if len(envOpts.SystemdKubelet) > 0 {
		if err := a.writeServiceDropinConfig("kubelet", kubeletServiceDropinPath, envOpts.SystemdKubelet); err != nil {
			return fmt.Errorf("failed to write kubelet environment config: %w", err)
		}
	}

	// Configure containerd-specific environment variables
	if len(envOpts.SystemdContainerd) > 0 {
		if err := a.writeServiceDropinConfig("containerd", containerdServiceDropinPath, envOpts.SystemdContainerd); err != nil {
			return fmt.Errorf("failed to write containerd environment config: %w", err)
		}
	}

	// Reload systemd configuration once after all config files are written
	zap.L().Info("Reloading systemd configuration")
	if output, err := exec.Command("systemctl", "daemon-reload").CombinedOutput(); err != nil {
		return fmt.Errorf("failed to reload systemd configuration: %w, output: %s", err, string(output))
	}

	return nil
}

func (a *environmentAspect) writeSystemdEnvironmentConfig(envVars map[string]string) error {
	if len(envVars) == 0 {
		return nil
	}

	zap.L().Info("Writing environment variables to systemd system.conf.d", zap.Int("count", len(envVars)))

	content := a.generateSystemdConfig(envVars)

	if err := util.WriteFileWithDir(systemdEnvironmentConfPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write systemd environment config: %w", err)
	}

	return nil
}

func (a *environmentAspect) generateSystemdConfig(envVars map[string]string) string {
	tmpl := template.Must(template.New("systemdConfig").Funcs(templateFuncs).Parse(systemdConfigTemplate))

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, envVars); err != nil {
		zap.L().Error("Failed to execute systemd config template", zap.Error(err))
		return ""
	}

	return buf.String()
}

func (a *environmentAspect) writeServiceDropinConfig(serviceName, dropinPath string, envVars map[string]string) error {
	if len(envVars) == 0 {
		return nil
	}

	zap.L().Info("Writing environment variables to service drop-in",
		zap.String("service", serviceName),
		zap.String("path", dropinPath),
		zap.Int("count", len(envVars)))

	content := a.generateServiceDropinConfig(envVars)

	if err := util.WriteFileWithDir(dropinPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write service drop-in config: %w", err)
	}

	return nil
}

func (a *environmentAspect) generateServiceDropinConfig(envVars map[string]string) string {
	tmpl := template.Must(template.New("serviceDropinConfig").Funcs(templateFuncs).Parse(serviceDropinConfigTemplate))

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, envVars); err != nil {
		zap.L().Error("Failed to execute service dropin config template", zap.Error(err))
		return ""
	}

	return buf.String()
}

func escapeSystemdValue(value string) string {
	// properly escapes special characters in systemd configuration values
	value = strings.ReplaceAll(value, "\\", "\\\\")
	value = strings.ReplaceAll(value, "\"", "\\\"")
	// systemd does not recognize \% as an escape sequence
	// so we use %% to specify a single percent sign
	// Ref: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Specifiers
	value = strings.ReplaceAll(value, "%", "%%")
	return value
}
