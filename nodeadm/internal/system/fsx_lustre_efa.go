package system

import (
	"os"
	"os/exec"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

const fsxLustreEFASetupScript = "/etc/eks/configure-efa-fsx-lustre-client/setup.sh"

func NewFSxLustreEFAAspect() SystemAspect {
	return &fsxLustreEFAAspect{}
}

type fsxLustreEFAAspect struct{}

func (a *fsxLustreEFAAspect) Name() string {
	return "fsx-lustre-efa"
}

func (a *fsxLustreEFAAspect) Setup(cfg *api.NodeConfig) error {
	if !api.IsFeatureEnabled(api.FSxLustreEFAClient, cfg.Spec.FeatureGates) {
		return nil
	}

	zap.L().Info("Configuring EFA for FSx Lustre client...")

	args := []string{"--configure-once"}
	if api.IsFeatureEnabled(api.FSxLustreEFAClientGDS, cfg.Spec.FeatureGates) {
		args = append(args, "--optimized-for-gds")
	}

	// #nosec G204 Subprocess launched with variable
	cmd := exec.Command(fsxLustreEFASetupScript, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
