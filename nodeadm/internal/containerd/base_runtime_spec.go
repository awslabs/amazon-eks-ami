package containerd

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
)

const containerdBaseRuntimeSpecFile = "/etc/containerd/base-runtime-spec.json"

//go:embed base-runtime-spec.json
var defaultBaseRuntimeSpecData string

func writeBaseRuntimeSpec(cfg *api.NodeConfig) error {
	zap.L().Info("Writing containerd base runtime spec...", zap.String("path", containerdBaseRuntimeSpecFile))
	baseRuntimeSpecData := defaultBaseRuntimeSpecData
	if len(cfg.Spec.Containerd.BaseRuntimeSpec) > 0 {
		var defaultBaseRuntimeSpecMap api.InlineDocument
		if err := json.Unmarshal([]byte(defaultBaseRuntimeSpecData), &defaultBaseRuntimeSpecMap); err != nil {
			return fmt.Errorf("failed to unmarshal default base runtime spec: %v", err)
		}
		mergedBaseRuntimeSpecMap, err := util.Merge(defaultBaseRuntimeSpecMap, cfg.Spec.Containerd.BaseRuntimeSpec, json.Marshal, json.Unmarshal)
		if err != nil {
			return err
		}
		mergedBaseRuntimeSpecData, err := json.MarshalIndent(mergedBaseRuntimeSpecMap, "", strings.Repeat(" ", 4))
		if err != nil {
			return err
		}
		baseRuntimeSpecData = string(mergedBaseRuntimeSpecData)
	}
	return util.WriteFileWithDir(containerdBaseRuntimeSpecFile, []byte(baseRuntimeSpecData), containerdConfigPerm)
}
