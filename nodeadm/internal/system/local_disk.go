package system

import (
	"fmt"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const localDiskAspectName = "LocalDisk"

func NewLocalDiskAspect() SystemAspect {
	return &localDiskAspect{}
}

type localDiskAspect struct{}

func (a *localDiskAspect) Name() string {
	return localDiskAspectName
}

const localDiskServiceDropinPath = "/etc/systemd/system/setup-local-disks.service.d/00-strategy.conf"

const localDiskServiceDropin = `[Service]
Environment=LOCAL_DISK_STRATEGY=%s`

func (a *localDiskAspect) Configure(cfg *api.NodeConfig) error {
	if cfg.Spec.Instance.LocalStorage.Strategy == "" {
		return nil
	}
	strategy := strings.ToLower(string(cfg.Spec.Instance.LocalStorage.Strategy))
	dropinConf := fmt.Sprintf(localDiskServiceDropin, strategy)
	return util.WriteFileWithDir(localDiskServiceDropinPath, []byte(dropinConf), 0644)
}
