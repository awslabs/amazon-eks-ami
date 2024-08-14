package containerd

import (
	"io/fs"
	"reflect"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

type MockCommandExecutor struct {
	Output []byte
	Err    error
}

func (m MockCommandExecutor) CombinedOutput(name string, arg ...string) ([]byte, error) {
	return m.Output, m.Err
}

type MockFileWriter struct {
	Err error
}

func (m MockFileWriter) WriteFileWithDir(filePath string, data []byte, perm fs.FileMode) error {
	return m.Err
}

func TestApplyInstanceTypeMixins(t *testing.T) {
	var neuronExpectedOutput = []byte(`default_runtime_name = 'neuron'
version = 2

[grpc]
address = '/run/foo/foo.sock'

[plugins]
[plugins.'io.containerd.grpc.v1.cri']
[plugins.'io.containerd.grpc.v1.cri'.containerd]
[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes]
[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.neuron]
[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.neuron.options]
BinaryName = '/opt/aws/neuron/bin/oci_neuron_hook_wrapper.sh'
`)

	var nvidiaExpectedOutput = []byte(`version = 2

[grpc]
address = '/run/foo/foo.sock'

[plugins]
[plugins.'io.containerd.grpc.v1.cri']
[plugins.'io.containerd.grpc.v1.cri'.containerd]
default_runtime_name = 'nvidia'

[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes]
[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.nvidia]
privileged_without_host_devices = false
runtime_engine = ''
runtime_root = ''
runtime_type = 'io.containerd.runc.v2'

[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.nvidia.options]
BinaryName = '/usr/bin/nvidia-container-runtime'
`)

	var nonAcceleratedExpectedOutput = []byte(`
version = 2
[grpc]
address = '/run/foo/foo.sock'
`)
	var tests = []struct {
		name           string
		instanceType   string
		expectedOutput []byte
		expectedError  error
	}{
		{instanceType: "inf1.xlarge", expectedOutput: neuronExpectedOutput, expectedError: nil},
		// code not implemented yet
		{instanceType: "p5.xlarge", expectedOutput: nvidiaExpectedOutput, expectedError: nil},
		// non accelerated instance
		{instanceType: "m5.xlarge", expectedOutput: nonAcceleratedExpectedOutput, expectedError: nil},
	}
	for _, test := range tests {
		var mockConfig = []byte(`
version = 2
[grpc]
address = '/run/foo/foo.sock'
`)
		mockOutput := []byte(`
version=2

[plugins]

[plugins."io.containerd.grpc.v1.cri"]

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name="nvidia"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
privileged_without_host_devices=false
runtime_engine=""
runtime_root=""
runtime_type="io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
BinaryName="/usr/bin/nvidia-container-runtime"
`)

		execCommand = MockCommandExecutor{
			Output: mockOutput,
			Err:    nil,
		}
		fileWriter = MockFileWriter{
			Err: nil,
		}

		err := applyInstanceTypeMixins(&api.NodeConfig{
			Status: api.NodeConfigStatus{
				Instance: api.InstanceDetails{
					Type: test.instanceType,
				},
			},
		}, &mockConfig)

		if err != test.expectedError {
			t.Fatalf("unexpected error: %v", err)
		}

		if !reflect.DeepEqual(mockConfig, test.expectedOutput) {
			t.Fatalf("unexpected output: %s, expecting: %s", mockConfig, test.expectedOutput)
		}
	}
}
