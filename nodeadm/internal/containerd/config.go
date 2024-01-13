package containerd

import (
	"bytes"
	_ "embed"
	"os"
	"path"
	"text/template"

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
	SandboxImage      string
	ImportPathPattern string
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
	pauseContainerImage, err := util.GetPauseContainer(cfg.Status.Instance.Region)
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
