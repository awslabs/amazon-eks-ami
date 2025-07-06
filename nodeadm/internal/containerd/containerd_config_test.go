package containerd

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/pelletier/go-toml/v2"
	"github.com/stretchr/testify/assert"
)

func TestContainerdConfigWithUserConfigAndFastContainerImagePullFeature(t *testing.T) {
	cfg := &api.NodeConfig{
		Spec: api.NodeConfigSpec{
			FeatureGates: map[api.Feature]bool{
				api.FastContainerImagePull: true,
			},
			Containerd: api.ContainerdOptions{
				Config: api.ContainerdConfig(`
[plugins.'io.containerd.grpc.v1.cri'.registry.mirrors]
"docker.io" = ["https://my-custom-mirror.example.com"]
`),
			},
		},
	}
	containerdConfig, err := combineContainerdConfigs(cfg)
	assert.NoError(t, err)

	// Parse the containerdConfig
	var configMap map[string]interface{}
	err = toml.Unmarshal(containerdConfig, &configMap)
	assert.NoError(t, err)

	plugins, ok := configMap["plugins"].(map[string]interface{})
	assert.True(t, ok)
	criPlugin, ok := plugins["io.containerd.grpc.v1.cri"].(map[string]interface{})
	assert.True(t, ok)

	// Verify user config
	registry, ok := criPlugin["registry"].(map[string]interface{})
	assert.True(t, ok)

	mirrors, ok := registry["mirrors"].(map[string]interface{})
	assert.True(t, ok)

	dockerMirrors, ok := mirrors["docker.io"].([]interface{})
	assert.True(t, ok)
	assert.ElementsMatch(t, []interface{}{"https://my-custom-mirror.example.com"}, dockerMirrors, "User config was not merged correctly with the containerd config")

	// Verify containerd snapshotter
	containerdSettings, ok := criPlugin["containerd"].(map[string]interface{})
	assert.True(t, ok)
	assert.Equal(t, "soci", containerdSettings["snapshotter"], "Snapshotter config was not merged correctly with the containerd config")
}

func TestContainerdConfigWithoutFastContainerImagePullFeature(t *testing.T) {
	cfg := &api.NodeConfig{}

	containerdConfig, err := combineContainerdConfigs(cfg)
	assert.NoError(t, err)

	// Parse the containerdConfig
	var configMap map[string]interface{}
	err = toml.Unmarshal(containerdConfig, &configMap)
	assert.NoError(t, err)

	// Verify containerd settings
	plugins, ok := configMap["plugins"].(map[string]interface{})
	assert.True(t, ok)
	criPlugin, ok := plugins["io.containerd.grpc.v1.cri"].(map[string]interface{})
	assert.True(t, ok)
	containerdSettings, ok := criPlugin["containerd"].(map[string]interface{})
	assert.True(t, ok)

	snapshotter, exists := containerdSettings["snapshotter"]
	if exists {
		assert.NotEqual(t, "soci", snapshotter, "snapshotter should not be set to soci when feature is disabled")
	}
}

func TestContainerdConfigWithFastContainerImagePullFeature(t *testing.T) {
	cfg := &api.NodeConfig{
		Spec: api.NodeConfigSpec{
			FeatureGates: map[api.Feature]bool{
				api.FastContainerImagePull: true,
			},
		},
	}

	containerdConfig, err := combineContainerdConfigs(cfg)
	assert.NoError(t, err)

	// Parse the containerdConfig
	var configMap map[string]interface{}
	err = toml.Unmarshal(containerdConfig, &configMap)
	assert.NoError(t, err)

	// Verify containerd settings
	proxyPlugins, ok := configMap["proxy_plugins"].(map[string]interface{})
	assert.True(t, ok)
	soci, ok := proxyPlugins["soci"].(map[string]interface{})
	assert.True(t, ok)
	assert.Equal(t, "snapshot", soci["type"], "incorrect type for proxy_plugin ")

	// Verify containerd snapshotter
	plugins, ok := configMap["plugins"].(map[string]interface{})
	assert.True(t, ok)
	criPlugin, ok := plugins["io.containerd.grpc.v1.cri"].(map[string]interface{})
	assert.True(t, ok)
	containerdSettings, ok := criPlugin["containerd"].(map[string]interface{})
	assert.True(t, ok)
	assert.Equal(t, "soci", containerdSettings["snapshotter"], "incorrect snapshotter configuration")
}
