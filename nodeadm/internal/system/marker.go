package system

import (
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const markerPath = "/run/nodeadm/init"

// / Creates a marker file to indicate that nodeadm's run phase has been started.
func NewMarkerAspect() SystemAspect {
	return &markerAspect{}
}

type markerAspect struct{}

func MarkerPath() string {
	return markerPath
}

func (a *markerAspect) Name() string {
	return "marker"
}

func (a *markerAspect) Setup(*api.NodeConfig) error {
	if _, err := os.Stat("/run/cloud-init/result.json"); os.IsNotExist(err) {
		zap.L().Warn("cloud-init result file /run/cloud-init/result.json does not exist. Do not manually call nodeadm from user data")
	}

	return util.WriteFileWithDir(markerPath, nil, 0644)
}
