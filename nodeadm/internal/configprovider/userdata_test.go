package configprovider

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
	"k8s.io/apimachinery/pkg/runtime"
)

func Test_decompressIfGZIP(t *testing.T) {
	expected := []byte("hello, world!")
	compressed, err := compressAsGZIP(expected)
	if err != nil {
		t.Fatal(err)
	}
	actual, err := decompressIfGZIP(compressed)
	if err != nil {
		t.Fatalf("failed to decompress GZIP: %v", err)
	}
	assert.Equal(t, expected, actual)
}

func mustCompressAsGZIP(t *testing.T, data []byte) []byte {
	compressedData, err := compressAsGZIP(data)
	if err != nil {
		t.Errorf("failed to compress as GZIP: %v", err)
	}
	return compressedData
}

func compressAsGZIP(data []byte) ([]byte, error) {
	var compressed bytes.Buffer
	writer := gzip.NewWriter(&compressed)
	n, err := writer.Write(data)
	if err != nil {
		return nil, fmt.Errorf("failed to write data to GZIP writer: %v", err)
	}
	if n != len(data) {
		return nil, fmt.Errorf("data written to GZIP writer doesn't match input (%d): %d", len(data), n)
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("unable to close GZIP writer: %v", err)
	}
	return compressed.Bytes(), nil
}

type testUserDataProvider struct {
	userData []byte
	err      error
}

func (p *testUserDataProvider) GetUserData() ([]byte, error) {
	return p.userData, p.err
}

func Test_Provide(t *testing.T) {
	testCases := []struct {
		scenario           string
		expectedNodeConfig api.NodeConfig
		userData           []byte
		isErrorExpected    bool
	}{
		{
			scenario: "multiple NodeConfigs in MIME multi-part should be merged",
			userData: linesToBytes(
				"MIME-Version: 1.0",
				`Content-Type: multipart/mixed; boundary="BOUNDARY"`,
				"",
				"--BOUNDARY",
				"Content-Type: application/node.eks.aws",
				"",
				"---",
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
				"",
				"--BOUNDARY",
				"Content-Type: application/node.eks.aws",
				"",
				"---",
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
				"",
				"--BOUNDARY--",
			),
			expectedNodeConfig: api.NodeConfig{
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
			},
		},
		{
			scenario: "GZIP NodeConfig",
			userData: mustCompressAsGZIP(t,
				linesToBytes(
					"---",
					"apiVersion: node.eks.aws/v1alpha1",
					"kind: NodeConfig",
					"spec:",
					"  cluster:",
					"    name: my-cluster",
					"    apiServerEndpoint: https://example.com",
					"    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=",
				),
			),
			expectedNodeConfig: api.NodeConfig{
				Spec: api.NodeConfigSpec{
					Cluster: api.ClusterDetails{
						Name:                 "my-cluster",
						APIServerEndpoint:    "https://example.com",
						CertificateAuthority: []byte("certificateAuthority"),
					},
				},
			},
		},
		{
			scenario: "GZIP multi-part MIME",
			userData: mustCompressAsGZIP(t,
				linesToBytes(
					"MIME-Version: 1.0",
					`Content-Type: multipart/mixed; boundary="BOUNDARY"`,
					"",
					"--BOUNDARY",
					"Content-Type: application/node.eks.aws",
					"",
					"---",
					"apiVersion: node.eks.aws/v1alpha1",
					"kind: NodeConfig",
					"spec:",
					"  cluster:",
					"    name: my-cluster",
					"    apiServerEndpoint: https://example.com",
					"    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=",
					"",
					"--BOUNDARY--",
				),
			),
			expectedNodeConfig: api.NodeConfig{
				Spec: api.NodeConfigSpec{
					Cluster: api.ClusterDetails{
						Name:                 "my-cluster",
						APIServerEndpoint:    "https://example.com",
						CertificateAuthority: []byte("certificateAuthority"),
					},
				},
			},
		},
		{
			scenario: "multi-part MIME with GZIP NodeConfig part",
			userData: appendByteSlices(
				linesToBytes(
					"MIME-Version: 1.0",
					`Content-Type: multipart/mixed; boundary="BOUNDARY"`,
					"",
					"--BOUNDARY",
					"Content-Type: application/node.eks.aws",
					"",
					"",
				),
				mustCompressAsGZIP(t,
					linesToBytes(
						"---",
						"apiVersion: node.eks.aws/v1alpha1",
						"kind: NodeConfig",
						"spec:",
						"  cluster:",
						"    name: my-cluster",
						"    apiServerEndpoint: https://example.com",
						"    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=",
					),
				),
				linesToBytes(
					"",
					"--BOUNDARY--",
				),
			),
			expectedNodeConfig: api.NodeConfig{
				Spec: api.NodeConfigSpec{
					Cluster: api.ClusterDetails{
						Name:                 "my-cluster",
						APIServerEndpoint:    "https://example.com",
						CertificateAuthority: []byte("certificateAuthority"),
					},
				},
			},
		},
		{
			scenario: "base64 encoded, gzip compressed multi-part MIME document",
			userData: []byte("H4sIAONcTmYAA12PT0/CQBDF7/spNty3tXpbwwGQACbUBLXKcegOdtP9l90p0m9vS4xBbjPvvfll3sI7QkfirQ8oue0M6QCRcqvPqB75wXdOQeynk+1mu5y/vJdPs91+wsZNVBiT9k7yIrtjTIjrCFv8A0MIRtdAQzx3XmGGbcrgO41ngkHQf6xrNz8VYEIDBWu1U5KXgzdwj/qLpYC1ZJzXpkuEcRw5d2DHEr34VS/iAH/FeMK4dCp47Ujyhigkmed4BhsMZrW3l2iNkfRx/BNnHTU+auol399XvVoZCx9lo1bVXH3u/OHhOah1O72tPZT5AWxxqkxSAQAA"),
			expectedNodeConfig: api.NodeConfig{
				Spec: api.NodeConfigSpec{
					Cluster: api.ClusterDetails{
						Name:                 "my-cluster",
						APIServerEndpoint:    "https://example.com",
						CertificateAuthority: []byte("certificateAuthority"),
					},
				},
			},
		},
	}

	for i, testCase := range testCases {
		t.Run(fmt.Sprintf("%d_%s", i, testCase.scenario), func(t *testing.T) {
			configProvider := userDataConfigProvider{
				userDataProvider: &testUserDataProvider{
					userData: testCase.userData,
				},
			}
			t.Logf("test case user data:\n%s", string(testCase.userData))
			actualNodeConfig, err := configProvider.Provide()
			if testCase.isErrorExpected {
				assert.NotNil(t, err)
				assert.Nil(t, actualNodeConfig)
			} else {
				assert.Nil(t, err)
				if assert.NotNil(t, actualNodeConfig) {
					assert.Equal(t, testCase.expectedNodeConfig, *actualNodeConfig)
				}
			}
		})
	}
}

func linesToBytes(lines ...string) []byte {
	var buf bytes.Buffer
	for i, line := range lines {
		if i > 0 {
			buf.WriteString("\n")
		}
		buf.WriteString(line)
	}
	return buf.Bytes()
}

func appendByteSlices(slices ...[]byte) []byte {
	var res []byte
	for _, slice := range slices {
		res = append(res, slice...)
	}
	return res
}
