package configprovider

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestFileConfigProvider_Directory(t *testing.T) {
	tempDir := t.TempDir()

	// fileName -> content
	files := map[string]string{
		"a.yaml": `---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: test-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
`,
		"b.yml": `---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    cidr: 10.100.0.0/16
  kubelet:
    flags:
      - --v=2
`,
		"c.json": `{
  "apiVersion": "node.eks.aws/v1alpha1",
  "kind": "NodeConfig",
  "spec": {
    "kubelet": {
      "flags": ["--node-labels=env=test"]
    }
  }
}`,
	}

	for filename, content := range files {
		filePath := filepath.Join(tempDir, filename)
		if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
			t.Fatalf("Failed to write test file %s: %v", filename, err)
		}
	}

	// Also create a non-config file that should be ignored
	if err := os.WriteFile(filepath.Join(tempDir, "ignore.txt"), []byte("ignore me"), 0644); err != nil {
		t.Fatalf("Failed to write ignore file: %v", err)
	}

	provider := NewFileConfigProvider(tempDir)
	config, err := provider.Provide()
	assert.Nil(t, err, "directory config provider failed")

	// from a.yaml
	assert.Equal(t, "test-cluster", config.Spec.Cluster.Name, "merged config cluster name is not correct")

	// from b.yml
	assert.Equal(t, "10.100.0.0/16", config.Spec.Cluster.CIDR, "merged config cluster CIDR is not correct")

	// from both b.yml and c.json
	var actualKubeletFlags []string
	for _, kubeletFlag := range config.Spec.Kubelet.Flags {
		actualKubeletFlags = append(actualKubeletFlags, kubeletFlag)
	}
	assert.Equal(t, []string{"--v=2", "--node-labels=env=test"}, actualKubeletFlags, "merged config kubelet flags is not correct")
}

func TestFileConfigProvider_EmptyDirectory(t *testing.T) {
	tempDir := t.TempDir()

	// Create a non-config file
	if err := os.WriteFile(filepath.Join(tempDir, "readme.txt"), []byte("no configs here"), 0644); err != nil {
		t.Fatalf("Failed to write non-config file: %v", err)
	}

	provider := NewFileConfigProvider(tempDir)
	config, err := provider.Provide()
	assert.Nil(t, config)
	assert.ErrorIs(t, err, ErrNoConfigInDirectory)
}

func TestFileConfigProvider_SingleFile(t *testing.T) {
	tempFile, err := os.CreateTemp("", "nodeconfig-single-*.yaml")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())

	config := `---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: single-file-cluster
`

	if _, err := tempFile.WriteString(config); err != nil {
		t.Fatalf("Failed to write to temp file: %v", err)
	}
	tempFile.Close()

	provider := NewFileConfigProvider(tempFile.Name())
	result, err := provider.Provide()
	assert.Nil(t, err, "unexpected error from file config provider")

	assert.Equal(t, "single-file-cluster", result.Spec.Cluster.Name)
}

func TestFileConfigProvider_isConfigFile(t *testing.T) {
	provider := &fileConfigProvider{}

	testCases := []struct {
		filename string
		expected bool
	}{
		{"config.yaml", true},
		{"config.yml", true},
		{"config.json", true},
		{"config.txt", false},
		{"config", false},
		{"yaml", false},
		{"readme.md", false},
		{"config.yaml.bak", false},
		{"00-systemd-lookin-dropin.conf", false},
	}

	for _, tc := range testCases {
		result := provider.isConfigFile(tc.filename)
		if result != tc.expected {
			t.Errorf("isConfigFile(%s) = %v, expected %v", tc.filename, result, tc.expected)
		}
	}
}
