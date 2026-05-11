package containerd

import (
	"fmt"
	"os"
	"os/exec"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	// pauseImageArchive is the path to the pre-cached pause container image tarball,
	// created during AMI build by the cache-pause-container script.
	pauseImageArchive = "/etc/eks/pause.tar"

	// sociDependencyDropInPath is the systemd drop-in that makes containerd.service
	// depend on soci-snapshotter.service. This ensures the SOCI gRPC server is
	// fully ready (Type=notify) before containerd is considered active.
	sociDependencyDropInPath = "/etc/systemd/system/containerd.service.d/10-soci-snapshotter.conf"
	sociDependencyDropIn     = `[Unit]
Requires=soci-snapshotter.service
After=soci-snapshotter.service
`
)

// writeSOCIServiceDependency writes a systemd drop-in for containerd.service that
// adds a hard dependency on soci-snapshotter.service. Because soci-snapshotter is
// Type=notify, systemd will not consider it active until its gRPC server sends
// READY=1. This guarantees that when EnsureRunning() returns after starting
// containerd, the SOCI snapshotter is fully initialized and ready to serve requests.
func writeSOCIServiceDependency(cfg *api.NodeConfig, resources system.Resources) error {
	if !UseSOCISnapshotter(cfg, resources) {
		return nil
	}
	zap.L().Info("Writing SOCI dependency drop-in for containerd.service")
	if err := util.WriteFileWithDir(sociDependencyDropInPath, []byte(sociDependencyDropIn), configPerm); err != nil {
		return fmt.Errorf("writing SOCI dependency drop-in: %w", err)
	}
	if output, err := exec.Command("systemctl", "daemon-reload").CombinedOutput(); err != nil {
		return fmt.Errorf("reloading systemd after writing drop-in: %w, output: %s", err, string(output))
	}
	return nil
}

// importSandboxImageForSOCI imports the pre-cached pause image tarball into the
// SOCI snapshotter's store. This is necessary because the pause image is cached
// during AMI build using the default overlayfs snapshotter, so its layers are not
// available in the SOCI snapshotter's store. Without this, containerd 2.2.3 would
// attempt to fetch the pause image layer headers from ECR at sandbox creation time,
// which fails because ECR credentials are not yet available (kubelet's credential
// provider hasn't initialized).
//
// By the time this function runs, the SOCI snapshotter is guaranteed to be ready
// because writeSOCIServiceDependency() adds a systemd ordering constraint ensuring
// soci-snapshotter.service is active before containerd.service starts.
func importSandboxImageForSOCI() error {
	if _, err := os.Stat(pauseImageArchive); err != nil {
		if os.IsNotExist(err) {
			zap.L().Warn("Pause image archive not found, skipping SOCI import", zap.String("path", pauseImageArchive))
			return nil
		}
		return fmt.Errorf("checking pause image archive: %w", err)
	}

	zap.L().Info("Importing pause image into SOCI snapshotter", zap.String("path", pauseImageArchive))
	cmd := exec.Command("ctr",
		"--namespace", "k8s.io",
		"images", "import",
		"--snapshotter", "soci",
		"--discard-unpacked-layers=false",
		"--local",
		pauseImageArchive,
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("importing pause image into SOCI snapshotter: %w, output: %s", err, string(output))
	}
	zap.L().Info("Successfully imported pause image into SOCI snapshotter")
	return nil
}
