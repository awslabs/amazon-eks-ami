package containerd

import (
	"bytes"
	_ "embed"
	"errors"
	"os"
	"os/exec"
	"regexp"
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
	containerdConfigFile  = "/etc/containerd/config.toml"
	containerdVersionFile = "/etc/eks/containerd-version.txt"
	containerdConfigPerm  = 0644
)

var (
	//go:embed config.template.toml
	containerdConfigTemplateData string
	//go:embed config2.template.toml
	containerdConfigTemplateData2 string
)

type containerdTemplateVars struct {
	EnableCDI         bool
	SandboxImage      string
	RuntimeName       string
	RuntimeBinaryName string
}

func getContainerdConfigTemplate() (*template.Template, error) {
	version, err := GetContainerdVersion()
	if err != nil {
		return &template.Template{}, err
	}
	// if version is like 2.x.x, use config2.template.toml
	if strings.HasPrefix(version, "2.") {
		return template.Must(template.New(containerdConfigFile).Parse(containerdConfigTemplateData2)), nil
	}
	return template.Must(template.New(containerdConfigFile).Parse(containerdConfigTemplateData)), nil
}

func GetContainerdVersion() (string, error) {
	rawVersion, err := GetContainerdVersionRaw()
	if err != nil {
		return "", err
	}
	semVerRegex := regexp.MustCompile(`[0-9]+\.[0-9]+.[0-9]+`)
	return semVerRegex.FindString(string(rawVersion)), nil
}

func GetContainerdVersionRaw() ([]byte, error) {
	if _, err := os.Stat(containerdVersionFile); errors.Is(err, os.ErrNotExist) {
		zap.L().Info("Reading containerd version from executable")
		return exec.Command("containerd", "--version").Output()
	} else if err != nil {
		return nil, err
	}
	zap.L().Info("Reading containerd version from file", zap.String("path", containerdVersionFile))
	return os.ReadFile(containerdVersionFile)
}

func writeContainerdConfig(cfg *api.NodeConfig) error {
	if err := writeBaseRuntimeSpec(cfg); err != nil {
		return err
	}

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

func generateContainerdConfig(cfg *api.NodeConfig) ([]byte, error) {
	instanceOptions := applyInstanceTypeMixins(cfg.Status.Instance.Type)

	configVars := containerdTemplateVars{
		SandboxImage:      cfg.Status.Defaults.SandboxImage,
		RuntimeBinaryName: instanceOptions.RuntimeBinaryName,
		RuntimeName:       instanceOptions.RuntimeName,
		EnableCDI:         semver.Compare(cfg.Status.KubeletVersion, "v1.32.0") >= 0,
	}
	var buf bytes.Buffer
	containerdConfigTemplate, err := getContainerdConfigTemplate()
	if err != nil {
		return nil, err
	}
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
