package nvidiacontainerruntime

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/pelletier/go-toml/v2"
	"github.com/stretchr/testify/assert"
)

func assertTOMLEqual(t *testing.T, expected, actual string) {
	t.Helper()
	var expectedMap, actualMap map[string]any
	assert.NoError(t, toml.Unmarshal([]byte(expected), &expectedMap))
	assert.NoError(t, toml.Unmarshal([]byte(actual), &actualMap))
	assert.Equal(t, expectedMap, actualMap)
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	assert.NoError(t, err)
	return string(data)
}

func TestCombineConfigs(t *testing.T) {
	tests := []struct {
		name           string
		existingConfig string
		userConfig     api.NvidiaContainerRuntimeConfig
		expectedConfig string
	}{
		{
			name:           "no existing config",
			existingConfig: "",
			userConfig:     "accept-nvidia-visible-devices-envvar-when-unprivileged = false",
			expectedConfig: "accept-nvidia-visible-devices-envvar-when-unprivileged = false",
		},
		{
			name: "user config merged over existing config",
			existingConfig: `
#accept-nvidia-visible-devices-as-volume-mounts = false
#accept-nvidia-visible-devices-envvar-when-unprivileged = true
supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"

[nvidia-container-cli]
ldconfig = "@/sbin/ldconfig"
load-kmods = true

[nvidia-container-runtime]
log-level = "info"
mode = "auto"
runtimes = ["runc", "crun"]
`,
			userConfig: `
accept-nvidia-visible-devices-as-volume-mounts = true
accept-nvidia-visible-devices-envvar-when-unprivileged = false

[nvidia-container-runtime]
log-level = "debug"
runtimes = ["runc"]
`,
			expectedConfig: `
accept-nvidia-visible-devices-as-volume-mounts = true
accept-nvidia-visible-devices-envvar-when-unprivileged = false
supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"

[nvidia-container-cli]
ldconfig = "@/sbin/ldconfig"
load-kmods = true

[nvidia-container-runtime]
log-level = "debug"
mode = "auto"
runtimes = ["runc"]
`,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			config, err := combineConfigs([]byte(test.existingConfig), test.userConfig)
			assert.NoError(t, err)
			assertTOMLEqual(t, test.expectedConfig, string(config))
		})
	}
}

func TestUpdateConfig(t *testing.T) {
	const shippedConfig = `#accept-nvidia-visible-devices-as-volume-mounts = false

[nvidia-container-runtime]
mode = "auto"
`

	t.Run("unset config leaves the file untouched", func(t *testing.T) {
		configPath := filepath.Join(t.TempDir(), "config.toml")
		originalConfigPath := filepath.Join(filepath.Dir(configPath), ".config.toml.orig")
		assert.NoError(t, os.WriteFile(configPath, []byte(shippedConfig), 0644))

		assert.NoError(t, updateConfig(configPath, originalConfigPath, ""))
		assert.Equal(t, shippedConfig, readFile(t, configPath))
		assert.NoFileExists(t, originalConfigPath)
	})

	t.Run("removed keys revert and removed config restores the original", func(t *testing.T) {
		configPath := filepath.Join(t.TempDir(), "config.toml")
		originalConfigPath := filepath.Join(filepath.Dir(configPath), ".config.toml.orig")
		assert.NoError(t, os.WriteFile(configPath, []byte(shippedConfig), 0644))

		assert.NoError(t, updateConfig(configPath, originalConfigPath, `
accept-nvidia-visible-devices-as-volume-mounts = true
accept-nvidia-visible-devices-envvar-when-unprivileged = false`))
		assert.Equal(t, shippedConfig, readFile(t, originalConfigPath))
		assertTOMLEqual(t, `
accept-nvidia-visible-devices-as-volume-mounts = true
accept-nvidia-visible-devices-envvar-when-unprivileged = false
[nvidia-container-runtime]
mode = "auto"`, readFile(t, configPath))

		assert.NoError(t, updateConfig(configPath, originalConfigPath, "accept-nvidia-visible-devices-envvar-when-unprivileged = false"))
		assert.Equal(t, shippedConfig, readFile(t, originalConfigPath))
		assertTOMLEqual(t, `
accept-nvidia-visible-devices-envvar-when-unprivileged = false
[nvidia-container-runtime]
mode = "auto"`, readFile(t, configPath))

		assert.NoError(t, updateConfig(configPath, originalConfigPath, ""))
		assert.Equal(t, shippedConfig, readFile(t, configPath))
		assert.NoFileExists(t, originalConfigPath)
	})

	t.Run("no shipped config file", func(t *testing.T) {
		configPath := filepath.Join(t.TempDir(), "config.toml")
		originalConfigPath := filepath.Join(filepath.Dir(configPath), ".config.toml.orig")

		assert.NoError(t, updateConfig(configPath, originalConfigPath, "accept-nvidia-visible-devices-envvar-when-unprivileged = false"))
		assert.Equal(t, "", readFile(t, originalConfigPath))
		assertTOMLEqual(t, "accept-nvidia-visible-devices-envvar-when-unprivileged = false", readFile(t, configPath))
	})
}
