package system

import (
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const markerPath = "/run/nodeadm/init"

// osManagedNoManageENIsMarkerPath is how the udev-triggered net-manager, which
// has no access to the NodeConfig, learns the OSManagedNoManageENIs gate is on.
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

	// feature marker must be written before the run marker (broker checks the run
	// marker first) to avoid a window where a no_manage ENI gets cached as ManagerCNI.
	if api.IsFeatureEnabled(api.OSManagedNoManageENIs, cfg.Spec.FeatureGates) {
		if err := util.WriteFileWithDir(osManagedNoManageENIsMarkerPath, nil, 0644); err != nil {
			return err
		}
	} else {
		// so that disabling the gate takes effect on a re-run, not just a reboot.
		if err := os.Remove(osManagedNoManageENIsMarkerPath); err != nil && !os.IsNotExist(err) {
			return err
		}
	}

	return util.WriteFileWithDir(markerPath, nil, 0644)
}
