package api

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/pelletier/go-toml/v2"
	"github.com/stretchr/testify/assert"
	"sigs.k8s.io/yaml"
)

// dropInPath is the pod isolation NodeConfig drop-in as it ships in the packer
// overlay. The AMI installs it to /etc/eks/nodeadm.d/10-pod-isolation.yaml,
// where nodeadm-run.service reads it as a config source.
const dropInPath = "../../../templates/al2023/runtime/pod-isolation/10-pod-isolation.yaml"

// TestPodIsolationDropInParses guards the drop-in against silent breakage. It is
// the only NodeConfig the AMI ships itself, and nothing else would catch a typo
// in a field name: an unparseable or misspelled drop-in does not fail the packer
// build, it fails at node boot after the AMI is already published.
func TestPodIsolationDropInParses(t *testing.T) {
	data, err := os.ReadFile(filepath.Clean(dropInPath))
	assert.NoError(t, err)

	var nodeConfig NodeConfig
	// UnmarshalStrict rejects unknown fields, so a field name that does not
	// exist on NodeConfig fails here rather than being silently dropped.
	assert.NoError(t, yaml.UnmarshalStrict(data, &nodeConfig))

	assert.Equal(t, "node.eks.aws/v1alpha1", nodeConfig.APIVersion)
	assert.Equal(t, "NodeConfig", nodeConfig.Kind)

	// The containerd half: both runtime handlers plus the content-store setting
	// the shim depends on, as valid TOML.
	var containerdConfig map[string]interface{}
	assert.NoError(t, toml.Unmarshal([]byte(nodeConfig.Spec.Containerd.Config), &containerdConfig))
	assert.Contains(t, string(nodeConfig.Spec.Containerd.Config), "runtimes.isolated-sandbox")
	assert.Contains(t, string(nodeConfig.Spec.Containerd.Config), "runtimes.confidential-sandbox")
	assert.Contains(t, string(nodeConfig.Spec.Containerd.Config), "discard_unpacked_layers = false")

	// The kubelet half. Setting any kubelet config is also what makes nodeadm
	// pass --config-dir to kubelet, so an empty map here would mean the
	// endpoint override never reaches kubelet at all.
	assert.NotEmpty(t, nodeConfig.Spec.Kubelet.Config)
	assert.Contains(t, nodeConfig.Spec.Kubelet.Config, "containerRuntimeEndpoint")

	// Without this label a sandboxed pod is rejected by the NodeAffinity
	// predicate, because admission puts the label in the pod's node selector.
	// The node still reports sandbox capacity, so the failure does not look like
	// a missing label.
	assert.Contains(t, nodeConfig.Spec.Kubelet.Flags,
		"--node-labels=eks.amazonaws.com/nitro-sandbox=true")
}

// TestPodIsolationDropInMergesWithUserData asserts the drop-in adds to a
// cluster's own containerd config rather than replacing it. Drop-ins take
// precedence over user data, so a plain string override here would silently
// discard whatever the cluster had configured.
func TestPodIsolationDropInMergesWithUserData(t *testing.T) {
	data, err := os.ReadFile(filepath.Clean(dropInPath))
	assert.NoError(t, err)

	var dropIn NodeConfig
	assert.NoError(t, yaml.UnmarshalStrict(data, &dropIn))

	userData := NodeConfig{
		Spec: NodeConfigSpec{
			Containerd: ContainerdOptions{
				Config: `[plugins.'io.containerd.cri.v1.runtime']
enable_unprivileged_ports = true`,
			},
			Kubelet: KubeletOptions{
				Flags: []string{"--node-labels=example.com/pool=general"},
			},
		},
	}

	assert.NoError(t, userData.Merge(&dropIn))

	merged := string(userData.Spec.Containerd.Config)
	assert.Contains(t, merged, "enable_unprivileged_ports", "user data setting must survive the merge")
	assert.Contains(t, merged, "isolated-sandbox", "drop-in runtime handler must be present")

	// Kubelet flags append rather than replace, so a cluster that sets its own
	// --node-labels keeps them alongside the sandbox label. Replacing instead
	// would strip a cluster's labels off every sandbox-capable node.
	assert.Contains(t, userData.Spec.Kubelet.Flags, "--node-labels=example.com/pool=general")
	assert.Contains(t, userData.Spec.Kubelet.Flags, "--node-labels=eks.amazonaws.com/nitro-sandbox=true")
}
