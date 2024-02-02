package containerd

import (
	"fmt"
	"os/exec"
	"regexp"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/containerd/containerd/integration/remote"
	"github.com/grpc-ecosystem/go-grpc-middleware/retry"
	"go.uber.org/zap"
	"google.golang.org/grpc"
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
	ecrUserToken, err := util.GetAuthorizationToken(cfg.Status.Instance.Region)
	if err != nil {
		return err
	}

	zap.L().Info("Pulling sandbox image..", zap.String("image", sandboxImage))
	client, err := remote.NewImageService(ContainerRuntimeEndpoint, 3*time.Second)
	if err != nil {
		return err
	}
	imageSpec := &v1.ImageSpec{Image: sandboxImage}
	authConfig := &v1.AuthConfig{Auth: ecrUserToken}
	callOptions := []grpc.CallOption{
		grpc_retry.WithMax(3),
		grpc_retry.WithBackoff(grpc_retry.BackoffExponentialWithJitter(5*time.Second, 0.2)),
	}
	imageRef, err := client.PullImage(imageSpec, authConfig, nil, callOptions...)
	if err != nil {
		return err
	}

	zap.L().Info("Finished pulling sandbox image", zap.String("image-ref", imageRef))
	return nil
}
