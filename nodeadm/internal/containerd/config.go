package containerd

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/base64"
	"os"
	"os/exec"
	"path"
	"strings"
	"text/template"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util/toml"
	"go.uber.org/zap"
)

const (
	containerdConfigFile = "/etc/containerd/config.toml"
	containerdConfigPerm = 0644
)

var (
	//go:embed config.template.toml
	containerdConfigTemplateData string
	containerdConfigTemplate     = template.Must(template.New(containerdConfigFile).Parse(containerdConfigTemplateData))
)

type containerdConfigDefaults struct {
	SandboxImage string
}

func writeContainerdConfig(c *api.NodeConfig) error {
	// TODO: check if the user supplied a sandbox image first
	pauseContainerImage, err := util.GetPauseContainer(c.Status.Instance.Region)
	if err != nil {
		return err
	}

	configDefaults := containerdConfigDefaults{
		SandboxImage: pauseContainerImage,
	}

	var buf bytes.Buffer
	if err := containerdConfigTemplate.Execute(&buf, configDefaults); err != nil {
		return err
	}
	containerdConfig := buf.String()

	config, err := getMergedConfig(c, containerdConfig)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(path.Dir(containerdConfigFile), containerdConfigPerm); err != nil {
		return err
	}
	return os.WriteFile(containerdConfigFile, []byte(config), containerdConfigPerm)
}

func getMergedConfig(c *api.NodeConfig, defaultConfig string) (string, error) {
	if c.Spec.Containerd.Config.Inline != "" {
		if c.Spec.Containerd.Config.MergeWithDefaults {
			mergedConfig, err := toml.Merge(defaultConfig, c.Spec.Containerd.Config.Inline)
			if err != nil {
				return "", err
			}
			return *mergedConfig, nil
		} else {
			return c.Spec.Containerd.Config.Inline, nil
		}
	} else if c.Spec.Containerd.Config.Source != "" {
		panic("TODO")
	} else {
		return defaultConfig, nil
	}
}

func cacheSandboxImage(c *api.NodeConfig) error {
	// TODO: pull this value from the config
	sandboxImage, err := util.GetPauseContainer(c.Status.Instance.Region)
	if err != nil {
		return err
	}

	zap.L().Info("Checking if sandbox image is cached..")
	imageList, err := exec.Command("ctr", "--namespace", "k8s.io", "image", "ls").Output()
	if err != nil {
		return err
	}
	// exit early if the image already exists
	if strings.Contains(string(imageList), sandboxImage) {
		return nil
	}

	zap.L().Info("Started pulling sandbox image", zap.String("image", sandboxImage))
	zap.L().Info("Fetching ECR authorization token..")
	ecrUserToken, err := getEcrAuthorizationToken(c.Status.Instance.Region)
	if err != nil {
		return err
	}
	fetchCommand := exec.Command("ctr", "--namespace", "k8s.io", "content", "fetch", sandboxImage, "--user", ecrUserToken)

	// TODO: use a retry policy
	if _, err := fetchCommand.Output(); err != nil {
		return err
	}

	zap.L().Info("Finished pulling sandbox image", zap.String("image", sandboxImage))
	return nil
}

func getEcrAuthorizationToken(awsRegion string) (string, error) {
	awsConfig, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(awsRegion))
	if err != nil {
		return "", err
	}
	ecrClient := ecr.NewFromConfig(awsConfig)
	token, err := ecrClient.GetAuthorizationToken(context.TODO(), &ecr.GetAuthorizationTokenInput{})
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
