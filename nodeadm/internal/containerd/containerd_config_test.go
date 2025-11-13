package containerd

import (
	"fmt"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/pelletier/go-toml/v2"
	"github.com/stretchr/testify/assert"
)

func TestContainerdConfigWithUserConfigAndFastImagePullFeature(t *testing.T) {
	cfg := &api.NodeConfig{
		Spec: api.NodeConfigSpec{
			FeatureGates: map[api.Feature]bool{
				api.FastImagePull: true,
			},
			Containerd: api.ContainerdOptions{
				Config: api.ContainerdConfig(`
[plugins.'io.containerd.grpc.v1.cri'.registry.mirrors]
"docker.io" = ["https://my-custom-mirror.example.com"]
`),
			},
		},
	}
	resources := system.FakeResources{Cpu: 8, Memory: 16 * 1024 * 1024 * 1024}
	template, err := getConfigTemplateVersion(cfg, false)
	assert.NoError(t, err)
	containerdConfig, err := generateContainerdConfig(cfg, resources, template)
	assert.NoError(t, err)
	containerdConfig, err = combineContainerdConfigs(containerdConfig, cfg.Spec.Containerd.Config)
	assert.NoError(t, err)

	// Parse the containerdConfig
	var configMap map[string]any
	err = toml.Unmarshal(containerdConfig, &configMap)
	assert.NoError(t, err)

	plugins, ok := configMap["plugins"].(map[string]any)
	assert.True(t, ok)
	criPlugin, ok := plugins["io.containerd.grpc.v1.cri"].(map[string]any)
	assert.True(t, ok)

	// Verify user config
	registry, ok := criPlugin["registry"].(map[string]any)
	assert.True(t, ok)

	mirrors, ok := registry["mirrors"].(map[string]any)
	assert.True(t, ok)

	dockerMirrors, ok := mirrors["docker.io"].([]any)
	assert.True(t, ok)
	assert.ElementsMatch(t, []any{"https://my-custom-mirror.example.com"}, dockerMirrors, "User config was not merged correctly with the containerd config")

	// Verify containerd snapshotter
	containerdSettings, ok := criPlugin["containerd"].(map[string]any)
	assert.True(t, ok)
	assert.Equal(t, "soci", containerdSettings["snapshotter"], "Snapshotter config was not merged correctly with the containerd config")
}

func TestContainerdConfig(t *testing.T) {
	tests := []struct {
		cfg               *api.NodeConfig
		resources         system.Resources
		isContainerdV2    bool
		expectSOCIEnabled bool
	}{
		{
			cfg:            &api.NodeConfig{},
			resources:      system.FakeResources{Cpu: 4, Memory: 7 * 1024 * 1024 * 1024},
			isContainerdV2: false,
			// Flag not enabled
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:      system.FakeResources{Cpu: 2, Memory: 4 * 1024 * 1024 * 1024},
			isContainerdV2: false,
			// Cpu too low
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:      system.FakeResources{Cpu: 4, Memory: 6 * 1024 * 1024 * 1024},
			isContainerdV2: false,
			// Memory too low
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:         system.FakeResources{Cpu: 4, Memory: 7.5 * 1024 * 1024 * 1024},
			isContainerdV2:    false,
			expectSOCIEnabled: true,
		},
		{
			cfg:            &api.NodeConfig{},
			resources:      system.FakeResources{Cpu: 4, Memory: 7 * 1024 * 1024 * 1024},
			isContainerdV2: true,
			// Flag not enabled
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:      system.FakeResources{Cpu: 2, Memory: 4 * 1024 * 1024 * 1024},
			isContainerdV2: true,
			// Cpu too low
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:      system.FakeResources{Cpu: 4, Memory: 6 * 1024 * 1024 * 1024},
			isContainerdV2: true,
			// Memory too low
			expectSOCIEnabled: false,
		},
		{
			cfg: &api.NodeConfig{
				Spec: api.NodeConfigSpec{
					FeatureGates: map[api.Feature]bool{
						api.FastImagePull: true,
					},
				},
			},
			resources:         system.FakeResources{Cpu: 4, Memory: 7.5 * 1024 * 1024 * 1024},
			isContainerdV2:    true,
			expectSOCIEnabled: true,
		},
	}

	for i, test := range tests {
		t.Run(fmt.Sprintf("Case%d", i), func(t *testing.T) {
			template, err := getConfigTemplateVersion(test.cfg, test.isContainerdV2)
			assert.NoError(t, err)
			containerdConfig, err := generateContainerdConfig(test.cfg, test.resources, template)
			assert.NoError(t, err)

			var configMap map[string]any
			err = toml.Unmarshal(containerdConfig, &configMap)
			assert.NoError(t, err)

			var containerdSettings map[string]any
			if test.isContainerdV2 {
				plugins, ok := configMap["plugins"].(map[string]any)
				assert.True(t, ok)
				containerdSettings, ok = plugins["io.containerd.cri.v1.images"].(map[string]any)
				assert.True(t, ok)
			} else {
				plugins, ok := configMap["plugins"].(map[string]any)
				assert.True(t, ok)
				criPlugin, ok := plugins["io.containerd.grpc.v1.cri"].(map[string]any)
				assert.True(t, ok)
				containerdSettings, ok = criPlugin["containerd"].(map[string]any)
				assert.True(t, ok)

			}

			if test.expectSOCIEnabled {
				proxyPlugins, ok := configMap["proxy_plugins"].(map[string]any)
				assert.True(t, ok)
				soci, ok := proxyPlugins["soci"].(map[string]any)
				assert.True(t, ok)
				assert.Equal(t, "snapshot", soci["type"], "incorrect type for proxy_plugin ")

				assert.Equal(t, "soci", containerdSettings["snapshotter"], "incorrect snapshotter configuration")
			} else {
				snapshotter, exists := containerdSettings["snapshotter"]
				if exists {
					assert.NotEqual(t, "soci", snapshotter, "snapshotter should not be set to soci when feature is disabled")
				}
			}
		})
	}
}
