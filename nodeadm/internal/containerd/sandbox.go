package containerd

import (
	"fmt"
	"os/exec"
	"regexp"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/containerd/containerd/integration/remote"
	"go.uber.org/zap"
	"google.golang.org/grpc/status"
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
	ecrUserToken, err := ecr.GetAuthorizationToken(cfg.Status.Instance.Region)
	if err != nil {
		return err
	}

	client, err := remote.NewImageService(ContainerRuntimeEndpoint, 5*time.Second)
	if err != nil {
		return err
	}
	imageSpec := &v1.ImageSpec{Image: sandboxImage}
	authConfig := &v1.AuthConfig{Auth: ecrUserToken}

	return util.RetryExponentialBackoff(time.Second,
		func(i *int, err error) bool {
			// Our process is responsible for ensuring containerd is running prior to
			// calling this function, so there should never be a terminal failure connecting
			// to the socket. If it does, don't count this retry against the total.
			// see: https://github.com/containerd/containerd/blob/26d6fd0c3fe505ad3bb1525c4514ef21c19c24d4/internal/cri/instrument/instrumented_service.go#L60
			if e, ok := status.FromError(err); ok {
				if e.Message() == "server is not initialized yet" {
					*i -= 1
				}
			}
			return *i < 5 // continue retries on 4 valid errors
		},
		func() error {
			zap.L().Info("Pulling sandbox image..", zap.String("image", sandboxImage))
			imageRef, err := client.PullImage(imageSpec, authConfig, nil)
			if err != nil {
				return err
			}
			zap.L().Info("Finished pulling sandbox image", zap.String("image-ref", imageRef))
			return nil
		},
	)
}
