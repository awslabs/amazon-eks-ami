package containerd

import (
	"bytes"
	"context"
	_ "embed"
	"os"
	"path"
	"text/template"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
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

type containerdTemplateVars struct {
	SandboxImage string
}

func writeContainerdConfig(cfg *api.NodeConfig) error {
	containerdConfig, err := generateContainerdConfig(cfg)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(path.Dir(containerdConfigFile), containerdConfigPerm); err != nil {
		return err
	}
	return os.WriteFile(containerdConfigFile, containerdConfig, containerdConfigPerm)
}

func generateContainerdConfig(cfg *api.NodeConfig) ([]byte, error) {
	awsDomain, err := util.GetAwsDomain(context.TODO(), imds.New(imds.Options{}))
	if err != nil {
		return nil, err
	}
	ecrUri, err := util.GetEcrUri(util.GetEcrUriRequest{
		Region:    cfg.Status.Instance.Region,
		Domain:    awsDomain,
		AllowFips: true,
	})
	if err != nil {
		return nil, err
	}
	pauseContainerImage, err := util.GetPauseContainer(ecrUri)
	if err != nil {
		return nil, err
	}
	configVars := containerdTemplateVars{
		SandboxImage: pauseContainerImage,
	}
	var buf bytes.Buffer
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
