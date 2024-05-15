package api

import (
	"reflect"
	"testing"

	"github.com/pelletier/go-toml/v2"
)

func toInlineDocumentMust(m map[string]interface{}) InlineDocument {
	d, err := toInlineDocument(m)
	if err != nil {
		panic(err)
	}
	return d
}

// pass the toml through serialization and deserialization to get a normalized
// payload for tests that has deterministic ordering and formatting
func tomlNormalize(t string) string {
	var m map[string]interface{}
	if err := toml.Unmarshal([]byte(t), &m); err != nil {
		panic(err)
	}
	s, err := toml.Marshal(m)
	if err != nil {
		panic(err)
	}
	return string(s)
}

func TestMerge(t *testing.T) {
	var tests = []struct {
		name         string
		baseSpec     NodeConfigSpec
		patchSpec    NodeConfigSpec
		expectedSpec NodeConfigSpec
	}{
		{
			name: "merge with empty string field",
			baseSpec: NodeConfigSpec{
				Cluster: ClusterDetails{},
			},
			patchSpec: NodeConfigSpec{
				Cluster: ClusterDetails{Name: "override"},
			},
			expectedSpec: NodeConfigSpec{
				Cluster: ClusterDetails{Name: "override"},
			},
		},
		{
			name: "merge with existing string field",
			baseSpec: NodeConfigSpec{
				Cluster: ClusterDetails{Name: "previous"},
			},
			patchSpec: NodeConfigSpec{
				Cluster: ClusterDetails{Name: "next"},
			},
			expectedSpec: NodeConfigSpec{
				Cluster: ClusterDetails{Name: "next"},
			},
		},
		{
			name: "merge with deeply nested toml object",
			baseSpec: NodeConfigSpec{
				Containerd: ContainerdOptions{
					Config: "[a.b.c.d]\nf = 0",
				},
			},
			patchSpec: NodeConfigSpec{
				Containerd: ContainerdOptions{
					Config: "[a.b.c.d]\ne = 0",
				},
			},
			// This test is primarily for clarity on what happens during the
			// expansion of nested toml objects.
			expectedSpec: NodeConfigSpec{
				Containerd: ContainerdOptions{
					Config: "[a]\n[a.b]\n[a.b.c]\n[a.b.c.d]\ne = 0\nf = 0\n",
				},
			},
		},
		{
			name: "customer overrides orchestrator defaults",
			baseSpec: NodeConfigSpec{
				Cluster: ClusterDetails{
					Name:                 "example",
					APIServerEndpoint:    "http://example.com",
					CertificateAuthority: []byte("example data"),
					CIDR:                 "10.0.0.0/16",
				},
				Kubelet: KubeletOptions{
					Config: toInlineDocumentMust(map[string]interface{}{
						"logging": map[string]interface{}{
							"verbosity": 5,
						},
						"podsPerCore": 20,
					}),
					Flags: []string{
						"--node-labels=nodegroup=example",
						"--register-with-taints=the=taint:NoSchedule",
					},
				},
				Containerd: ContainerdOptions{
					Config: tomlNormalize(`
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name = "runc"
discard_unpacked_layers = true

[plugins."io.containerd.grpc.v1.cri"]
sandbox_image = "{{.SandboxImage}}"

[plugins."io.containerd.grpc.v1.cri".registry]
config_path = "/etc/containerd/certs.d:/etc/docker/certs.d"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
bin_dir = "/opt/cni/bin"
conf_dir = "/etc/cni/net.d"`),
				},
			},
			patchSpec: NodeConfigSpec{
				Kubelet: KubeletOptions{
					Config: toInlineDocumentMust(map[string]interface{}{
						"logging": map[string]interface{}{
							"verbosity": 2,
						},
						"maxPods": 150,
					}),
					Flags: []string{
						"--node-labels=nodegroup=user-set",
					},
				},
				Containerd: ContainerdOptions{
					Config: tomlNormalize(`
version = 2
[grpc]
address = "/run/containerd/containerd.sock.2"

[plugins."io.containerd.grpc.v1.cri".containerd]
discard_unpacked_layers = false`),
				},
			},
			expectedSpec: NodeConfigSpec{
				Cluster: ClusterDetails{
					Name:                 "example",
					APIServerEndpoint:    "http://example.com",
					CertificateAuthority: []byte("example data"),
					CIDR:                 "10.0.0.0/16",
				},
				Kubelet: KubeletOptions{
					Config: toInlineDocumentMust(map[string]interface{}{
						"logging": map[string]interface{}{
							"verbosity": 2,
						},
						"maxPods":     150,
						"podsPerCore": 20,
					}),
					Flags: []string{
						"--node-labels=nodegroup=example",
						"--register-with-taints=the=taint:NoSchedule",
						"--node-labels=nodegroup=user-set",
					},
				},
				Containerd: ContainerdOptions{
					Config: tomlNormalize(`
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
address = "/run/containerd/containerd.sock.2"

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name = "runc"
discard_unpacked_layers = false

[plugins."io.containerd.grpc.v1.cri"]
sandbox_image = "{{.SandboxImage}}"

[plugins."io.containerd.grpc.v1.cri".registry]
config_path = "/etc/containerd/certs.d:/etc/docker/certs.d"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".cni]
bin_dir = "/opt/cni/bin"
conf_dir = "/etc/cni/net.d"`),
				},
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			baseConfig := NodeConfig{Spec: test.baseSpec}
			patchConfig := NodeConfig{Spec: test.patchSpec}
			if err := baseConfig.Merge(&patchConfig); err != nil {
				t.Error(err)
			}
			expectedConfig := NodeConfig{Spec: test.expectedSpec}
			if !reflect.DeepEqual(expectedConfig, baseConfig) {
				t.Errorf("\nexpected: %+v\n\ngot:       %+v", expectedConfig, baseConfig)
			}
		})
	}
}
