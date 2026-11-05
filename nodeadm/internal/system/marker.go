package system

import (
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const markerPath = "/run/nodeadm/init"

// read by udev-net-manager, which has no NodeConfig.
const osManagedNoManageENIsMarkerPath = "/run/nodeadm/os-managed-no-manage-enis"

// / Creates a marker file to indicate that nodeadm's run phase has been started.
func NewMarkerAspect() SystemAspect {
	return &markerAspect{}
}

type markerAspect struct{}

func MarkerPath() string {
	return markerPath
}

func OSManagedNoManageENIsMarkerPath() string {
	return osManagedNoManageENIsMarkerPath
}

func (a *markerAspect) Name() string {
	return "marker"
}

func (a *markerAspect) Setup(cfg *api.NodeConfig) error {
	if _, err := os.Stat("/run/cloud-init/result.json"); os.IsNotExist(err) {
		zap.L().Warn("cloud-init result file /run/cloud-init/result.json does not exist. Do not manually call nodeadm from user data")
	}

	// written before the run marker so the broker never sees the gate as off.
	if api.IsFeatureEnabled(api.OSManagedNoManageENIs, cfg.Spec.FeatureGates) {
		if err := util.WriteFileWithDir(osManagedNoManageENIsMarkerPath, nil, 0644); err != nil {
			return err
		}
	}

	return util.WriteFileWithDir(markerPath, nil, 0644)
}
