package system

import (
	"bytes"
	_ "embed"
	"path/filepath"
	"text/template"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	systemdResolvedConfigDirPath = "/run/systemd/resolved.conf.d"
)

var (
	// see: https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html
	//go:embed resolve.conf.tpl
	systemdResolvedConfigTemplateString string
	systemdResolvedConfigTemplate       = template.Must(template.New("resolve").Parse(systemdResolvedConfigTemplateString))
)

// NewResolveAspect returns an aspect that configures network name resolution on
// the host.
func NewResolveAspect() SystemAspect {
	return &resolveAspect{}
}

type resolveAspect struct{}

func (a *resolveAspect) Name() string {
	return "resolve"
}

func (a *resolveAspect) Setup(cfg *api.NodeConfig) error {
	if len(cfg.Spec.Instance.Network.Domains) == 0 && len(cfg.Spec.Instance.Network.Nameservers) == 0 {
		return nil
	}

	configData, err := a.generateSystemdResolvedConfig(cfg.Spec.Instance.Network)
	if err != nil {
		return err
	}

	systemdResolvedConfigPath := filepath.Join(systemdResolvedConfigDirPath, "40-eks.conf")
	zap.L().Info("Writing systemd-resolved config...", zap.String("path", systemdResolvedConfigPath))
	if err := util.WriteFileWithDir(systemdResolvedConfigPath, configData, 0644); err != nil {
		return err
	}

	zap.L().Info("Reloading systemd-resolved...")
	if err := a.reloadSystemdResolved(); err != nil {
		return err
	}

	return nil
}

func (a *resolveAspect) generateSystemdResolvedConfig(options api.NetworkOptions) ([]byte, error) {
	type ResolveTemplateData struct {
		Nameservers []string
		Domains     []string
	}

	var buf bytes.Buffer
	if err := systemdResolvedConfigTemplate.Execute(&buf, ResolveTemplateData{
		Nameservers: options.Nameservers,
		Domains:     options.Domains,
	}); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

func (a *resolveAspect) reloadSystemdResolved() error {
	manager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	return manager.RestartDaemon("systemd-resolved")
}
