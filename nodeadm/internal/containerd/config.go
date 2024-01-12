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
	// Users can use the following import directory to add additional
	// configuration to containerd. The imports do not behave exactly like overrides.
	// see: https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md#format
	containerdImportDir         = "/etc/containerd/config.d"
	containerdImportFileMatcher = "*.toml"
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
	if err := os.MkdirAll(containerdImportDir, containerdConfigPerm); err != nil {
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
		ImportPathPattern: path.Join(containerdImportDir, containerdImportFileMatcher),
		SandboxImage:      pauseContainerImage,
	}
	var buf bytes.Buffer
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
