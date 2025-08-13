package kubelet

import (
	"os"
	"path"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
)

var (
	templatedDefaultCredentialProvider = `{
  "apiVersion": "kubelet.config.k8s.io/v1",
  "kind": "CredentialProviderConfig",
  "providers": [
    {
      "name": "true",
      "matchImages": [
        "*.dkr.ecr.*.amazonaws.com",
        "*.dkr-ecr.*.on.aws",
        "*.dkr.ecr.*.amazonaws.com.cn",
        "*.dkr-ecr.*.on.amazonwebservices.com.cn",
        "*.dkr.ecr-fips.*.amazonaws.com",
        "*.dkr-ecr-fips.*.on.aws",
        "*.dkr.ecr.*.c2s.ic.gov",
        "*.dkr.ecr.*.sc2s.sgov.gov",
        "*.dkr.ecr.*.cloud.adc-e.uk",
        "*.dkr.ecr.*.csp.hci.ic.gov"
      ],
      "defaultCacheDuration": "12h",
      "apiVersion": "credentialprovider.kubelet.k8s.io/v1"
    }
  ]
}`
	customCredentialProvider = `{
  "apiVersion": "{{.ConfigApiVersion}}",
  "kind": "CredentialProviderConfig",
  "providers": [
    {
      "name": "custom",
      "matchImages": [
        "custom-registry.example.com"
      ],
      "defaultCacheDuration": "12h",
      "apiVersion": "{{.ProviderApiVersion}}"
    }
  ]
}
`
	customTemplatedCredentialProvider = `{
  "apiVersion": "kubelet.config.k8s.io/v1",
  "kind": "CredentialProviderConfig",
  "providers": [
    {
      "name": "custom",
      "matchImages": [
        "custom-registry.example.com"
      ],
      "defaultCacheDuration": "12h",
      "apiVersion": "credentialprovider.kubelet.k8s.io/v1"
    }
  ]
}
`
)

func TestWriteImageCredentialProviderConfig(t *testing.T) {
	tempDir := t.TempDir()
	originalImageCredentialProviderConfigPath := imageCredentialProviderConfigPath
	t.Cleanup(func() {
		imageCredentialProviderConfigPath = originalImageCredentialProviderConfigPath
	})

	t.Setenv(ecrCredentialProviderBinPathEnvironmentName, "/usr/bin/true")

	imageCredentialProviderConfigPath = path.Join(tempDir, "image-credential-provider-config.json")
	k := kubelet{
		flags: make(map[string]string),
	}
	err := k.writeImageCredentialProviderConfig(&api.NodeConfig{
		Spec: api.NodeConfigSpec{
			Kubelet: api.KubeletOptions{},
		},
		Status: api.NodeConfigStatus{
			KubeletVersion: "v1.27.0",
		},
	})
	assert.NoError(t, err)
	assert.FileExists(t, imageCredentialProviderConfigPath)
	templatedConfig, err := os.ReadFile(imageCredentialProviderConfigPath)
	assert.NoError(t, err)
	assert.JSONEq(t, templatedDefaultCredentialProvider, string(templatedConfig))
}

func TestWriteCustomImageCredentialProviderConfig(t *testing.T) {
	tempDir := t.TempDir()
	originalImageCredentialProviderConfigPath := imageCredentialProviderConfigPath
	t.Cleanup(func() {
		imageCredentialProviderConfigPath = originalImageCredentialProviderConfigPath
	})

	t.Setenv(ecrCredentialProviderBinPathEnvironmentName, "/usr/bin/true")

	imageCredentialProviderConfigPath = path.Join(tempDir, "image-credential-provider-config.json")
	k := kubelet{
		flags: make(map[string]string),
	}
	err := k.writeImageCredentialProviderConfig(&api.NodeConfig{
		Spec: api.NodeConfigSpec{
			Kubelet: api.KubeletOptions{
				ImageCredentialProviderConfig: customCredentialProvider,
			},
		},
		Status: api.NodeConfigStatus{
			KubeletVersion: "v1.27.0",
		},
	})
	assert.NoError(t, err)
	assert.FileExists(t, imageCredentialProviderConfigPath)
	templatedConfig, err := os.ReadFile(imageCredentialProviderConfigPath)
	assert.NoError(t, err)
	assert.JSONEq(t, customTemplatedCredentialProvider, string(templatedConfig))
}
