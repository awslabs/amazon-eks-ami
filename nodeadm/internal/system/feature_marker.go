package system

import (
	"errors"
	"io/fs"
	"os"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

// read by udev-net-manager, which has no NodeConfig.
const eniTagsMarkerPath = "/run/nodeadm/eni-tags"

func ENITagsMarkerPath() string {
	return eniTagsMarkerPath
}

// NewFeatureMarkerAspect returns an aspect that mirrors feature gates read
// outside of nodeadm as marker files. It runs in the config phase, so the
// markers exist before the run marker.
func NewFeatureMarkerAspect() SystemAspect {
	return &featureMarkerAspect{eniTagsPath: eniTagsMarkerPath}
}

type featureMarkerAspect struct {
	eniTagsPath string
}

func (a *featureMarkerAspect) Name() string {
	return "feature-marker"
}

func (a *featureMarkerAspect) Setup(cfg *api.NodeConfig) error {
	if api.IsFeatureEnabled(api.ENITags, cfg.Spec.FeatureGates) {
		return util.WriteFileWithDir(a.eniTagsPath, nil, 0644)
	}
	if err := os.Remove(a.eniTagsPath); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	return nil
}
