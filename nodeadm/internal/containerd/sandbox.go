package containerd

import (
	"context"
	"fmt"
	"os/exec"
	"regexp"
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/containerd/containerd/integration/remote"
	"go.uber.org/zap"
	v1 "k8s.io/cri-api/pkg/apis/runtime/v1"
)

var containerdSandboxImageRegex = regexp.MustCompile(`sandbox_image = "(.*)"`)

func cacheSandboxImage(cfg *api.NodeConfig) error {
	zap.L().Info("Looking up current sandbox image in containerd config..")
	// capture the output of a `containerd config dump`, which is the final
	// containerd configuration used after all of the applied transformations
	dump, err := exec.Command("containerd", "config", "dump").Output()
	if err != nil {
		return err
	}
	matches := containerdSandboxImageRegex.FindSubmatch(dump)
	if matches == nil {
		return fmt.Errorf("sandbox image could not be found in containerd config")
	}
	sandboxImage := string(matches[1])
	zap.L().Info("Found sandbox image", zap.String("image", sandboxImage))

	zap.L().Info("Fetching ECR authorization token..")
	opts := []func(*config.LoadOptions) error{config.WithRegion(cfg.Status.Instance.Region)}
	if cfg.IsHybridNode() {
		opts = append(opts, config.WithSharedConfigFiles([]string{"/etc/eks/hybrid-config"}))
	}
	awsConfig, err := config.LoadDefaultConfig(context.Background(), opts...)
	if err != nil {
		return err
	}
	ecrUserToken, err := ecr.GetAuthorizationToken(awsConfig)
	if err != nil {
		return err
	}

	client, err := remote.NewImageService(ContainerRuntimeEndpoint, 5*time.Second)
	if err != nil {
		return err
	}
	imageSpec := &v1.ImageSpec{Image: sandboxImage}
	authConfig := &v1.AuthConfig{Auth: ecrUserToken}

	return util.RetryExponentialBackoff(3, 2*time.Second, func() error {
		zap.L().Info("Pulling sandbox image..", zap.String("image", sandboxImage))
		imageRef, err := client.PullImage(imageSpec, authConfig, nil)
		if err != nil {
			return err
		}
		zap.L().Info("Finished pulling sandbox image", zap.String("image-ref", imageRef))
		return nil
	})
}
