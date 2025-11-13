package containerd

import (
	"bytes"
	_ "embed"
	"fmt"
	"os/exec"
	"strings"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
	"golang.org/x/mod/semver"
)

const ContainerRuntimeEndpoint = "unix:///run/containerd/containerd.sock"

const (
	containerdConfigFile      = "/etc/containerd/config.toml"
	sociSnapshotterConfigFile = "/etc/soci-snapshotter-grpc/config.toml"
	configPerm                = 0644
)

var (
	//go:embed config.template.toml
	containerdConfigTemplateData string
	//go:embed config2.template.toml
	containerdConfigTemplateData2 string

	//go:embed snapshotter/soci-snapshotter.config.toml
	sociSnapshotterTemplateData []byte
)

type ConfigSchema string

const (
	ConfigSchemaV2 ConfigSchema = "2"
	ConfigSchemaV3 ConfigSchema = "3"

	gibibyte int64 = 1024 * 1024 * 1024
)

var containerdTemplateVersionMap = map[ConfigSchema]string{
	ConfigSchemaV2: containerdConfigTemplateData,
	ConfigSchemaV3: containerdConfigTemplateData2,
}

type containerdTemplateVars struct {
	EnableCDI          bool
	SandboxImage       string
	RuntimeName        string
	RuntimeBinaryName  string
	UseSOCISnapshotter bool
}

func writeContainerdConfig(cfg *api.NodeConfig, resources system.Resources) error {
	isContainerdV2, err := isContainerdV2()
	if err != nil {
		return err
	}
	templateVersion, err := getConfigTemplateVersion(cfg, isContainerdV2)
	if err != nil {
		return err
	}
	containerdConfig, err := generateContainerdConfig(cfg, resources, templateVersion)
	if err != nil {
		return err
	}
	containerdConfig, err = combineContainerdConfigs(containerdConfig, cfg.Spec.Containerd.Config)
	if err != nil {
		return err
	}

	zap.L().Info("Writing containerd config to file..", zap.String("path", containerdConfigFile))
	err = util.WriteFileWithDir(containerdConfigFile, containerdConfig, configPerm)
	if err != nil {
		return err
	}
	// configuration V3 template will be used for containerd 2.* by default, unless there are configuration V2 property passed in NodeConfig,
	// then need to run containerd config migrate. Need to run after write file because it only work for what already in the config file.
	if isContainerdV2 && templateVersion == ConfigSchemaV2 {
		zap.L().Info("Migrate containerd config to V3..", zap.String("path", containerdConfigFile))
		return migrateConfig()
	}
	return nil
}

func combineContainerdConfigs(configA []byte, configB api.ContainerdConfig) ([]byte, error) {
	// because the logic in containerd's import merge decides to completely
	// overwrite entire sections, we want to implement this merging ourselves.
	// see: https://github.com/containerd/containerd/blob/a91b05d99ceac46329be06eb43f7ae10b89aad45/cmd/containerd/server/config/config.go#L407-L431
	if len(configB) <= 0 {
		return configA, nil
	}

	containerdConfigMap, err := util.Merge(configA, []byte(configB), toml.Marshal, toml.Unmarshal)
	if err != nil {
		return nil, err
	}

	return toml.Marshal(containerdConfigMap)

}

func generateContainerdConfig(cfg *api.NodeConfig, resources system.Resources, templateVersion ConfigSchema) ([]byte, error) {
	runtimeOptions := getRuntimeOptions(cfg)

	configVars := containerdTemplateVars{
		SandboxImage:       cfg.Status.Defaults.SandboxImage,
		RuntimeBinaryName:  runtimeOptions.RuntimeBinaryPath,
		RuntimeName:        runtimeOptions.RuntimeName,
		EnableCDI:          semver.Compare(cfg.Status.KubeletVersion, "v1.32.0") >= 0,
		UseSOCISnapshotter: UseSOCISnapshotter(cfg, resources),
	}
	var buf bytes.Buffer
	containerdConfigTemplate := template.Must(template.New(containerdConfigFile).Parse(containerdTemplateVersionMap[templateVersion]))
	if err := containerdConfigTemplate.Execute(&buf, configVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func getConfigTemplateVersion(cfg *api.NodeConfig, isContainerdV2 bool) (ConfigSchema, error) {
	config := string(cfg.Spec.Containerd.Config)
	if isContainerdV2 {
		// side case: if V2 config passed in nodeConfig when using containerd 2.*, we use V2 config template and will run containerd config migrate
		if len(cfg.Spec.Containerd.Config) > 0 && !Version3configInNodeConfig(config) {
			return ConfigSchemaV2, nil
		}
		return ConfigSchemaV3, nil
	} else {
		// side case: if v3 config passed in nodeConfig when using containerd 1.*, throw error
		if len(cfg.Spec.Containerd.Config) > 0 && Version3configInNodeConfig(config) {
			zap.L().Error("Invalid containerd config passed, containerd 1.* doesn't support containerd configuration V3 properties")
			return "", fmt.Errorf("failed to get config template version")
		}
		return ConfigSchemaV2, nil
	}
}

// Most proprty are moved under `io.containerd.cri.v1.runtime` and `io.containerd.cri.v1.images` in config v3, only a few left
// in `io.containerd.grpc.v1.cri` which is same as config V2. So assume it is config V2 if `io.containerd.grpc.v1.cri` detected
func Version3configInNodeConfig(config string) bool {
	return strings.Contains(config, "io.containerd.cri.v1.images") ||
		strings.Contains(config, "io.containerd.cri.v1.runtime")
}

func migrateConfig() error {
	migratedConfig, err := exec.Command("containerd", "config", "migrate").Output()
	if err != nil {
		return err
	}
	return util.WriteFileWithDir(containerdConfigFile, migratedConfig, configPerm)
}

func writeSnapshotterConfig(cfg *api.NodeConfig, resources system.Resources) error {
	if UseSOCISnapshotter(cfg, resources) {
		return util.WriteFileWithDir(sociSnapshotterConfigFile, sociSnapshotterTemplateData, configPerm)
	}

	return nil
}

func UseSOCISnapshotter(cfg *api.NodeConfig, resources system.Resources) bool {
	if !api.IsFeatureEnabled(api.FastImagePull, cfg.Spec.FeatureGates) {
		return false
	}

	totalCPUMillicores, err := resources.GetMilliNumCores()
	if err != nil {
		zap.L().Error("Error getting total CPU millicores", zap.Error(err))
		return false
	}

	totalMemory, err := resources.GetOnlineMemory()
	if err != nil {
		zap.L().Error("Error getting total memory", zap.Error(err))
		return false
	}

	// This should be usable on most xlarge instance types.
	// Lower the memory threshold since an instance will have less available RAM shown in the kernel than its specs.
	// e.g. in my test a c6a.2xlarge with 16GiB of memory showed 15.75GiB available.
	return totalMemory >= 7*gibibyte && totalCPUMillicores >= 4000
}
