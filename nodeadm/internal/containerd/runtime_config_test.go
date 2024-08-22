package containerd

import (
	"reflect"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

func TestApplyInstanceTypeMixins(t *testing.T) {

	var nvidiaExpectedOutput = []byte(`version = 2

[grpc]
address = '/run/foo/foo.sock'

[plugins]
[plugins.'io.containerd.grpc.v1.cri']
[plugins.'io.containerd.grpc.v1.cri'.containerd]
default_runtime_name = 'nvidia'
discard_unpacked_layers = true

[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes]
[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.nvidia]
base_runtime_spec = '/etc/containerd/base-runtime-spec.json'
runtime_type = 'io.containerd.runc.v2'

[plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.nvidia.options]
BinaryName = '/usr/bin/nvidia-container-runtime'
SystemdCgroup = true
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
