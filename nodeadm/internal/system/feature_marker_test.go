package system

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

func TestFeatureMarkerAspect(t *testing.T) {
	for _, tc := range []struct {
		name    string
		enabled bool
		existed bool
	}{
		{name: "enabled", enabled: true},
		{name: "enabled and already present", enabled: true, existed: true},
		{name: "disabled"},
		{name: "disabled removes a stale marker", existed: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "nodeadm", "eni-tags")
			if tc.existed {
				assert.NoError(t, util.WriteFileWithDir(path, nil, 0644))
			}
			cfg := &api.NodeConfig{Spec: api.NodeConfigSpec{FeatureGates: map[api.Feature]bool{api.ENITags: tc.enabled}}}
			a := &featureMarkerAspect{eniTagsPath: path}
			assert.NoError(t, a.Setup(cfg))
			exists, err := util.IsFilePathExists(path)
			assert.NoError(t, err)
			assert.Equal(t, tc.enabled, exists)
		})
	}
}
