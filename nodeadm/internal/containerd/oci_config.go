package containerd

import (
	"errors"
	"io/fs"
	"os/exec"
	"reflect"
	"slices"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"go.uber.org/zap"
)

type instanceTypeMixin struct {
	instanceFamilies []string
	apply            func(*[]byte) error
}

func (m *instanceTypeMixin) matches(cfg *api.NodeConfig) bool {
	instanceFamily := strings.Split(cfg.Status.Instance.Type, ".")[0]
	return slices.Contains(m.instanceFamilies, instanceFamily)
}

var (
	// TODO: fetch this list dynamically
	nvidiaInstances         = []string{"p3", "p3dn", "p4d", "p4de", "p5", "g4", "g4dn", "g5", "g6"}
	neuronInstances         = []string{"inf1", "inf2", "trn1", "trn1n"}
	NvidiaInstanceTypeMixin = instanceTypeMixin{
		instanceFamilies: nvidiaInstances,
		apply:            applyNvidia,
	}

	NeuronInstanceTypeMixin = instanceTypeMixin{
		instanceFamilies: neuronInstances,
		apply:            applyNeuron,
	}

	mixins = []instanceTypeMixin{
		NvidiaInstanceTypeMixin,
		NeuronInstanceTypeMixin,
	}
)

// applyInstanceTypeMixins adds the needed OCI hook options to containerd config.toml
// based on the instance family
func applyInstanceTypeMixins(cfg *api.NodeConfig, containerdConfig *[]byte) error {
	for _, mixin := range mixins {
		if mixin.matches(cfg) {
			if err := mixin.apply(containerdConfig); err != nil {
				return err
			}
			return nil
		}
	}
	zap.L().Info("No containerd OCI configuration needed..", zap.String("instanceType", cfg.Status.Instance.Type))
	return nil
}

type CommandExecutor interface {
	CombinedOutput(name string, arg ...string) ([]byte, error)
}

type RealCommandExecutor struct{}

func (r RealCommandExecutor) CombinedOutput(name string, arg ...string) ([]byte, error) {
	if isAllowedCommand(name, arg...) {
		cmd := exec.Command(name, arg...)
		return cmd.CombinedOutput()
	}
	return nil, errors.New("unrecognised command")

}

type FileWriter interface {
	WriteFileWithDir(filePath string, data []byte, perm fs.FileMode) error
}

type RealFileWriter struct{}

func (r RealFileWriter) WriteFileWithDir(filePath string, data []byte, perm fs.FileMode) error {
	return util.WriteFileWithDir(filePath, data, perm)
}

var execCommand CommandExecutor = RealCommandExecutor{}
var fileWriter FileWriter = RealFileWriter{}
var nvidiaCtkCommand = "/usr/bin/nvidia-ctk"
var nvidiaCtkParams = []string{"--quiet", "runtime", "configure", "--runtime=containerd", "--set-as-default", "--dry-run"}

func isAllowedCommand(command string, args ...string) bool {
	return command == "/usr/bin/nvidia-ctk" && reflect.DeepEqual(args, nvidiaCtkParams)
}

// applyNvidia adds the needed Nvidia containerd options using nvidia container toolkit:
// https://github.com/NVIDIA/nvidia-container-toolkit
func applyNvidia(containerdConfig *[]byte) error {
	zap.L().Info("Configuring Nvidia OCI hook..")
	// before calling nvidia-ctk, we'll write the generated containerd config first
	// nvidia-ctk will use it as a base
	err := fileWriter.WriteFileWithDir(containerdConfigFile, *containerdConfig, containerdConfigPerm)

	if err != nil {
		return err
	}

	output, err := execCommand.CombinedOutput(nvidiaCtkCommand, nvidiaCtkParams...)
	if err != nil {
		return err
	}

	if containerdConfig != nil {
		containerdConfigMap, err := util.Merge(*containerdConfig, output, toml.Marshal, toml.Unmarshal)
		if err != nil {
			return err
		}
		*containerdConfig, err = toml.Marshal(containerdConfigMap)
		if err != nil {
			return err
		}
	}

	return nil
}

// applyNeuron adds the needed Neuron containerd options as outlined here:
// https://awsdocs-neuron.readthedocs-hosted.com/en/latest/containers/tutorials/tutorial-oci-hook.html#for-containerd-runtime-setup-containerd-to-use-oci-neuron-oci-runtime
func applyNeuron(containerdConfig *[]byte) error {
	zap.L().Info("Configuring Neuron OCI hook..")
	neuronOptions := `
default_runtime_name = "neuron"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.neuron]
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.neuron.options]
BinaryName = "/opt/aws/neuron/bin/oci_neuron_hook_wrapper.sh"
`
	if containerdConfig != nil {
		containerdConfigMap, err := util.Merge(*containerdConfig, []byte(neuronOptions), toml.Marshal, toml.Unmarshal)
		if err != nil {
			return err
		}
		*containerdConfig, err = toml.Marshal(containerdConfigMap)
		if err != nil {
			return err
		}
	}
	return nil
}
