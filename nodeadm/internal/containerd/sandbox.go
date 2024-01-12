package containerd

import (
	"context"
	"encoding/base64"
	"fmt"
	"os/exec"
	"regexp"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"go.uber.org/zap"
)

var containerdSandboxImageRegex = regexp.MustCompile(`sandbox_image = "(.*)"`)

func cacheSandboxImage(cfg *api.NodeConfig) error {
	zap.L().Info("Looking up current sandbox image in containerd config..")
	// capture the output of a `containerd config dump`, which is the final
	// containerd configuration used after all of the applied transformation
	containerdConfigCommand := exec.Command("containerd", "config", "dump")
	dump, err := containerdConfigCommand.Output()
	if err != nil {
		return err
	}
	matches := containerdSandboxImageRegex.FindSubmatch(dump)
	if matches == nil {
		return fmt.Errorf("sandbox image could not be found in containerd config")
	}
	sandboxImage := string(matches[1])
	zap.L().Info("Found sandbox image", zap.String("image", sandboxImage))

	zap.L().Info("Checking if sandbox image is cached..")
	imageList, err := exec.Command("ctr", "--namespace", "k8s.io", "image", "ls").Output()
	if err != nil {
		return err
	}
	// exit early if the image already exists
	if strings.Contains(string(imageList), sandboxImage) {
		zap.L().Info("Sandbox image already exists.", zap.String("image", sandboxImage))
		return nil
	}

	zap.L().Info("Fetching ECR authorization token..")
	ecrUserToken, err := getEcrAuthorizationToken(cfg.Status.Instance.Region)
	if err != nil {
		return err
	}
	fetchCommand := exec.Command("ctr", "--namespace", "k8s.io", "content", "fetch", sandboxImage, "--user", ecrUserToken)

	// TODO: use a retry policy
	zap.L().Info("Pulling sandbox image..", zap.String("image", sandboxImage))
	if _, err := fetchCommand.Output(); err != nil {
		return err
	}

	zap.L().Info("Finished pulling sandbox image", zap.String("image", sandboxImage))
	return nil
}

func getEcrAuthorizationToken(awsRegion string) (string, error) {
	awsConfig, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		return "", err
	}
	ecrClient := ecr.NewFromConfig(awsConfig)
	token, err := ecrClient.GetAuthorizationToken(context.Background(), &ecr.GetAuthorizationTokenInput{})
	if err != nil {
		return "", err
	}

	authData := token.AuthorizationData[0].AuthorizationToken
	data, err := base64.StdEncoding.DecodeString(*authData)
	if err != nil {
		return "", err
	}

	return string(data), nil
}
