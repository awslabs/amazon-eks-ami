package api

import (
	"encoding/json"
	"reflect"
	"testing"
)

func indent(in string) string {
	var mid interface{}
	err := json.Unmarshal([]byte(in), &mid)
	if err != nil {
		panic(err)
	}
	out, err := json.MarshalIndent(&mid, "", "    ")
	if err != nil {
		panic(err)
	}
	return string(out)
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
			name: "customer overrides orchestrator defaults",
			baseSpec: NodeConfigSpec{
				Cluster: ClusterDetails{
					Name:                 "example",
					APIServerEndpoint:    "http://example.com",
					CertificateAuthority: []byte("example data"),
					CIDR:                 "10.0.0.0/16",
				},
				Kubelet: KubeletOptions{
					// Config: indent(`{"logging":{"verbosity":5},"podsPerCore":20}`),
					Flags: []string{
						"--node-labels=nodegroup=example",
						"--register-with-taints=the=taint:NoSchedule",
					},
				},
			},
			patchSpec: NodeConfigSpec{
				Kubelet: KubeletOptions{
					// Config: indent(`{"maxPods":150,"logging":{"verbosity":2}}`),
					Flags: []string{
						"--node-labels=nodegroup=user-set",
					},
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
					// Config: indent(`{"logging":{"verbosity":2},"podsPerCore":20,"maxPods":150}`),
					Flags: []string{
						"--node-labels=nodegroup=example",
						"--register-with-taints=the=taint:NoSchedule",
						"--node-labels=nodegroup=user-set",
					},
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
