package containerd

import (
	"bufio"
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
)

const ContainerRuntimeEndpoint = "unix:///run/containerd/containerd.sock"

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
	// write nodeadm's generated containerd config to the default path
	containerdConfig, err := generateContainerdConfig(cfg)
	if err != nil {
		return err
	}
	// because the logic in containerd's import merge decides to completely
	// overwrite entire sections, we want to implement this merging ourselves.
	// see: https://github.com/containerd/containerd/blob/a91b05d99ceac46329be06eb43f7ae10b89aad45/cmd/containerd/server/config/config.go#L407-L431
	if len(cfg.Spec.Containerd.Config) > 0 {
		containerdConfigMap, err := util.Merge(containerdConfig, []byte(cfg.Spec.Containerd.Config), toml.Marshal, toml.Unmarshal)
		if err != nil {
			return err
		}
		containerdConfig, err = toml.Marshal(containerdConfigMap)
		if err != nil {
			return err
		}
	}

	zap.L().Info("Writing containerd config to file..", zap.String("path", containerdConfigFile))
	return util.WriteFileWithDir(containerdConfigFile, containerdConfig, containerdConfigPerm)
}

// readExistingContainerdConfig reads /etc/containerd/config.toml
// and returns lines that are not comments
func readExistingContainerdConfig() (string, error) {
	zap.L().Info("Reading existing config file...", zap.String("path", string(containerdConfigFile)))
	file, err := os.Open(containerdConfigFile)
	var contents strings.Builder
	if err != nil {
		return contents.String(), err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		// skip lines with comments
		if !strings.HasPrefix(line, "#") {
			contents.WriteString(fmt.Sprintln(line))
		}
	}

	if err := scanner.Err(); err != nil {
		return contents.String(), err
	}

	return contents.String(), nil
}

func generateContainerdConfig(cfg *api.NodeConfig) ([]byte, error) {
	existingConfig, err := readExistingContainerdConfig()
	if err != nil {
		return nil, err
	}
	configVars := containerdTemplateVars{
		SandboxImage: cfg.Status.Defaults.SandboxImage,
	}
	var buf bytes.Buffer
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}

	if existingConfig != "" {
		// merge existing config with the one comming from the template
		mergedConfigMap, err := util.Merge(buf.Bytes(), []byte(existingConfig), toml.Marshal, toml.Unmarshal)

		if err != nil {
			return nil, err
		}

		return toml.Marshal(mergedConfigMap)
	}

	return buf.Bytes(), nil
}
