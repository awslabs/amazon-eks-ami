package containerd

import (
	"bytes"
	_ "embed"
	"fmt"
	"os/exec"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
	"golang.org/x/mod/semver"
)

const ContainerRuntimeEndpoint = "unix:///run/containerd/containerd.sock"

const (
	containerdConfigFile = "/etc/containerd/config.toml"
	containerdConfigPerm = 0644
)

var (
	//go:embed config.template.toml
	containerdConfigTemplateData string
	//go:embed config2.template.toml
	containerdConfigTemplateData2 string
)

type TemplateVersion string

const (
	V2 TemplateVersion = "2"
	V3 TemplateVersion = "3"
)

var containerdTemplateVersionMap = map[TemplateVersion]string{
	V2: containerdConfigTemplateData,
	V3: containerdConfigTemplateData2,
}

type containerdTemplateVars struct {
	EnableCDI         bool
	SandboxImage      string
	RuntimeName       string
	RuntimeBinaryName string
}

func writeContainerdConfig(cfg *api.NodeConfig) error {
	isContainerdV2, err := isContainerdV2()
	if err != nil {
		return err
	}
	templateVersion, err := getConfigTemplateVersion(cfg, isContainerdV2)
	if err != nil {
		return err
	}
	containerdConfig, err := generateContainerdConfig(cfg, templateVersion)
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
	err = util.WriteFileWithDir(containerdConfigFile, containerdConfig, containerdConfigPerm)
	if err != nil {
		return err
	}
	// configuration V3 template will be used for containerd 2.* by default, unless there are configuration V2 property passed in NodeConfig,
	// then need to run containerd config migrate. Need to run after write file because it only work for what already in the config file.
	if isContainerdV2 && templateVersion == V2 {
		zap.L().Info("Migrate containerd config to V3..", zap.String("path", containerdConfigFile))
		return migrateConfig()
	}
	return nil
}

func generateContainerdConfig(cfg *api.NodeConfig, templateVersion TemplateVersion) ([]byte, error) {
	runtimeOptions := getRuntimeOptions(cfg)

	configVars := containerdTemplateVars{
		SandboxImage:      cfg.Status.Defaults.SandboxImage,
		RuntimeBinaryName: runtimeOptions.RuntimeBinaryPath,
		RuntimeName:       runtimeOptions.RuntimeName,
		EnableCDI:         semver.Compare(cfg.Status.KubeletVersion, "v1.32.0") >= 0,
	}
	var buf bytes.Buffer
	containerdConfigTemplate := template.Must(template.New(containerdConfigFile).Parse(containerdTemplateVersionMap[templateVersion]))
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func getConfigTemplateVersion(cfg *api.NodeConfig, isContainerdV2 bool) (TemplateVersion, error) {
	if isContainerdV2 {
		// side case: if v2 config passed in nodeConfig when using containerd 2.*, we use V2 config template and will run containerd config migrate
		if len(cfg.Spec.Containerd.Config) > 0 && !Version3configInNodeConfig(cfg) {
			return V2, nil
		}
		return V3, nil
	} else {
		// side case: if v3 config passed in nodeConfig when using containerd 1.*, throw error
		if len(cfg.Spec.Containerd.Config) > 0 && Version3configInNodeConfig(cfg) {
			zap.L().Error("Invalid containerd config passed, containerd 1.7.* doesn't support containerd configuration V3 properties")
			return "", fmt.Errorf("failed to get config template version")
		}
		return V2, nil
	}
}

// Most proprty are moved under `io.containerd.cri.v1.runtime` and `io.containerd.cri.v1.images` in config v3, only a few left
// in `io.containerd.grpc.v1.cri` which is same as config V2. So assume it is config V2 if `io.containerd.grpc.v1.cri` detected
func Version3configInNodeConfig(cfg *api.NodeConfig) bool {
	return strings.Contains(string(cfg.Spec.Containerd.Config), "io.containerd.cri.v1.images") ||
		strings.Contains(string(cfg.Spec.Containerd.Config), "io.containerd.cri.v1.runtime")
}

func migrateConfig() error {
	migratedConfig, err := exec.Command("containerd", "config", "migrate").Output()
	if err != nil {
		return err
	}
	return util.WriteFileWithDir(containerdConfigFile, migratedConfig, containerdConfigPerm)
}
