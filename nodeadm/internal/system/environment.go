package system

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"text/template"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	instanceEnvironmentAspectName = "instance-environment"
	nodeamdEnvironmentAspectName  = "nodeadm-environment"
	systemdEnvironmentConfPath    = "/etc/systemd/system.conf.d/environment.conf"
	serviceDropinPathBase         = "/etc/systemd/system"
)

const systemdConfigTemplate = `[Manager]
{{range .}}DefaultEnvironment="{{.Key}}={{escape .Value}}"
{{end}}`

const serviceDropinConfigTemplate = `[Service]
{{range .}}Environment="{{.Key}}={{escape .Value}}"
{{end}}`

var templateFuncs = template.FuncMap{
	"escape": escapeSystemdValue,
}

func NewNodeadmEnvironmentAspect() SystemAspect {
	return &nodeadmEnvironmentAspect{}
}

func NewInstanceEnvironmentAspect() SystemAspect {
	return &instanceEnvironmentAspect{}
}

type nodeadmEnvironmentAspect struct{}

type instanceEnvironmentAspect struct{}

func (a *nodeadmEnvironmentAspect) Name() string {
	return nodeamdEnvironmentAspectName
}

func (a *nodeadmEnvironmentAspect) Setup(cfg *api.NodeConfig) error {
	envOpts := cfg.Spec.Instance.Environment
	if defaultEnv, exists := envOpts["default"]; exists && len(defaultEnv) > 0 {
		for key, value := range defaultEnv {
			if err := os.Setenv(key, value); err != nil {
				zap.L().Warn("Failed to set environment variable", zap.String("key", key), zap.Error(err))
				continue
			}
			zap.L().Info("Set nodeadm environment variable", zap.String("key", key), zap.String("value", value))
		}
	}
	return nil
}

func (a *instanceEnvironmentAspect) Name() string {
	return instanceEnvironmentAspectName
}

func (a *instanceEnvironmentAspect) Setup(cfg *api.NodeConfig) error {
	envOpts := cfg.Spec.Instance.Environment

	// Check if any environment configuration exists. If nothing to configure, don't invoke systemctl daemon-reload
	if len(envOpts) == 0 {
		zap.L().Info("No environment variables to configure")
		return nil
	}

	return a.configureInstanceEnvironment(envOpts)
}

// configureInstanceEnvironment makes environment variables available system-wide and to specific services.
func (a *instanceEnvironmentAspect) configureInstanceEnvironment(envOpts api.EnvironmentOptions) error {

	zap.L().Info("All envOpts: ", zap.Any("=", envOpts))
	for serviceName, envVars := range envOpts {
		if len(envVars) > 0 {
			if serviceName == "default" {
				// Configure systemd system.conf.d for all services
				// Nodeadm will use the lowest precedence directive i.e. DefaultEnvironment= to configure environment
				// Note that EnvironmentFile= and Environment= directives will take precedence over DefaultEnvironment=.
				// Reference: systemd.exec(5) and systemd-system.conf(5) man pages
				// https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Environment
				if err := a.writeSystemdEnvironmentConfig(envOpts["default"]); err != nil {
					return fmt.Errorf("failed to write systemd environment config: %w", err)
				}
			} else {
				// Create a dropin config for all the services
				dropinPath := fmt.Sprintf("%s/%s.service.d/environment.conf", serviceDropinPathBase, serviceName)
				if err := a.writeServiceDropinConfig(serviceName, dropinPath, envVars); err != nil {
					return fmt.Errorf("failed to write %s environment config: %w", serviceName, err)
				}
			}
		}
	}

	// Reload systemd configuration once after all config files are written
	zap.L().Info("Reloading systemd configuration")
	if output, err := exec.Command("systemctl", "daemon-reload").CombinedOutput(); err != nil {
		return fmt.Errorf("failed to reload systemd configuration: %w, output: %s", err, string(output))
	}

	return nil
}

func (a *instanceEnvironmentAspect) writeSystemdEnvironmentConfig(envVars map[string]string) error {
	zap.L().Info("Writing environment variables to systemd system.conf.d", zap.Int("count", len(envVars)))

	content := a.generateEnvironmentConfig(envVars, systemdConfigTemplate)

	if err := util.WriteFileWithDir(systemdEnvironmentConfPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write systemd environment config: %w", err)
	}

	return nil
}

func (a *instanceEnvironmentAspect) writeServiceDropinConfig(serviceName, dropinPath string, envVars map[string]string) error {
	zap.L().Info("Writing environment variables to service drop-in",
		zap.String("service", serviceName),
		zap.String("path", dropinPath),
		zap.Int("count", len(envVars)))

	content := a.generateEnvironmentConfig(envVars, serviceDropinConfigTemplate)

	if err := util.WriteFileWithDir(dropinPath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write service drop-in config: %w", err)
	}

	return nil
}

func (c *instanceEnvironmentAspect) generateEnvironmentConfig(envVars map[string]string, templateStr string) string {
	// sort keys to generate a deterministic config output
	keys := make([]string, 0, len(envVars))
	for k := range envVars {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	configData := make([]struct{ Key, Value string }, len(keys))
	for i, k := range keys {
		configData[i] = struct{ Key, Value string }{k, envVars[k]}
	}

	tmpl := template.Must(template.New("envConfig").Funcs(templateFuncs).Parse(templateStr))
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, configData); err != nil {
		zap.L().Error("Failed to execute environment config template", zap.Error(err))
		return ""
	}

	return buf.String()
}

func escapeSystemdValue(value string) string {
	quotedValue := strconv.Quote(value)
	// Prevent specifier expansion in Environment=/DefaultEnvironment=
	// systemd does not recognize \% as an escape sequence
	// so we use %% to specify a single percent sign
	// Ref: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Specifiers
	quotedValue = strings.ReplaceAll(quotedValue, "%", "%%")
	// just the inner (escaped) content for VALUE (since KEY=VALUE is quoted outside)
	return strings.Trim(quotedValue, `"`)
}
