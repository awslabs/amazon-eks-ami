package system

import (
	"os"
	"os/exec"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

func NewLocalDiskAspect() SystemAspect {
	return &localDiskAspect{}
}

type localDiskAspect struct{}

func (a *localDiskAspect) Name() string {
	return "local-disk"
}

func (a *localDiskAspect) Setup(cfg *api.NodeConfig) error {
	if cfg.Spec.Instance.LocalStorage.Strategy == "" {
		zap.L().Info("Not configuring local disks!")
		return nil
	}
	strategy := strings.ToLower(string(cfg.Spec.Instance.LocalStorage.Strategy))
	args := []string{strategy}

	if cfg.Spec.Instance.LocalStorage.MountPath != "" {
		args = append(args, "--dir", cfg.Spec.Instance.LocalStorage.MountPath)
	}

	for _, mount := range cfg.Spec.Instance.LocalStorage.DisabledMounts {
		switch mount {
		case api.DisabledMountPodLogs:
			args = append(args, "--no-bind-pods-logs")
		case api.DisabledMountContainerd:
			args = append(args, "--no-bind-containerd")
		}
	}

	// #nosec G204 Subprocess launched with variable
	cmd := exec.Command("setup-local-disks", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
