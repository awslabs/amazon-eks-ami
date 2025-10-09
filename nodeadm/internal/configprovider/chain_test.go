package configprovider

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/stretchr/testify/assert"
	"k8s.io/apimachinery/pkg/runtime"
)

func TestChainConfigProvider_UserData(t *testing.T) {
	testCases := []struct {
		scenario    string
		userData    []byte
		expectedErr error
	}{
		{
			scenario: "no NodeConfigs in MIME multi-part user-data should return non-fatal error",
			userData: linesToBytes(
				"MIME-Version: 1.0",
				`Content-Type: multipart/mixed; boundary="BOUNDARY"`,
				"",
				"--BOUNDARY",
				"",
				"--BOUNDARY--",
			),
			expectedErr: ErrNoConfigInChain,
		},
		{
			scenario:    "missing NodeConfig in raw user-data should non-fatal error",
			userData:    linesToBytes(""),
			expectedErr: ErrNoConfigInChain,
		},
	}

	for i, testCase := range testCases {
		t.Run(fmt.Sprintf("%d_%s", i, testCase.scenario), func(t *testing.T) {
			imdsClient := imds.FakeIMDSClient{}
			imdsClient.GetUserDataFunc = func(ctx context.Context) ([]byte, error) {
				return testCase.userData, nil
			}

			chainProvider := configProviderChain{
				providers: []ConfigProvider{
					&userDataConfigProvider{
						userDataProvider: &imdsClient,
					},
				},
			}

			t.Logf("test case user data:\n%s", string(testCase.userData))
			_, err := chainProvider.Provide()
			if testCase.expectedErr != nil {
				assert.ErrorIs(t, err, testCase.expectedErr)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestChainConfigProvider_FileProvider(t *testing.T) {
	testCases := []struct {
		scenario        string
		providerSetupFn func(*testing.T, *fileConfigProvider)
		expectedErr     error
	}{
		{
			scenario: "no files in directory should return non-fatal error",
			providerSetupFn: func(t *testing.T, f *fileConfigProvider) {
				f.path = t.TempDir()
			},
			expectedErr: ErrNoConfigInChain,
		},
	}

	for i, testCase := range testCases {
		t.Run(fmt.Sprintf("%d_%s", i, testCase.scenario), func(t *testing.T) {
			fileProvider := &fileConfigProvider{}
			testCase.providerSetupFn(t, fileProvider)

			chainProvider := configProviderChain{
				providers: []ConfigProvider{fileProvider},
			}

			_, err := chainProvider.Provide()
			if testCase.expectedErr != nil {
				assert.ErrorIs(t, err, testCase.expectedErr)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestChainConfigProvider_MultiProvider(t *testing.T) {
	t.Run("Precedence", func(t *testing.T) {
		fileProvider1 := &fileConfigProvider{path: t.TempDir()}
		assert.NoError(t, os.WriteFile(filepath.Join(fileProvider1.path, "config.yaml"), linesToBytes(
			"apiVersion: node.eks.aws/v1alpha1",
			"kind: NodeConfig",
			"spec:",
			"  cluster:",
			"    name: my-cluster",
			"    apiServerEndpoint: https://example.com",
			"    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=",
			"    cidr: 10.100.0.0/16",
			"  kubelet:",
			"    config:",
			"      port: 1010",
			"      maxPods: 120",
			"    flags:",
			"      - --v=2",
			"      - --node-labels=foo=bar,nodegroup=test",
		), 0644))

		fileProvider2 := &fileConfigProvider{path: t.TempDir()}
		assert.NoError(t, os.WriteFile(filepath.Join(fileProvider2.path, "config.yaml"), linesToBytes(
			"apiVersion: node.eks.aws/v1alpha1",
			"kind: NodeConfig",
			"spec:",
			"  kubelet:",
			"    config:",
			"      maxPods: 150",
			"      podsPerCore: 20",
			"      systemReserved:",
			"        cpu: 150m",
			"    flags:",
			"      - --v=5",
			"      - --node-labels=foo=baz",
		), 0644))

		chainProvider := configProviderChain{
			providers: []ConfigProvider{
				fileProvider1,
				fileProvider2,
			},
		}

		nodeConfig, err := chainProvider.Provide()
		assert.NoError(t, err)
		assert.Equal(t, nodeConfig, &api.NodeConfig{
			Spec: api.NodeConfigSpec{
				Cluster: api.ClusterDetails{
					Name:                 "my-cluster",
					APIServerEndpoint:    "https://example.com",
					CertificateAuthority: []byte("certificateAuthority"),
					CIDR:                 "10.100.0.0/16",
				},
				Kubelet: api.KubeletOptions{
					Config: api.InlineDocument{
						"maxPods":        runtime.RawExtension{Raw: []byte("150")},
						"podsPerCore":    runtime.RawExtension{Raw: []byte("20")},
						"port":           runtime.RawExtension{Raw: []byte("1010")},
						"systemReserved": runtime.RawExtension{Raw: []byte(`{"cpu":"150m"}`)},
					},
					Flags: []string{
						"--v=2",
						"--node-labels=foo=bar,nodegroup=test",
						"--v=5",
						"--node-labels=foo=baz",
					},
				},
			},
		})
	})
}
