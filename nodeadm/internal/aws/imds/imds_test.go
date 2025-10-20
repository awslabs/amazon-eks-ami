package imds

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDynamicProxyFuncBehavior(t *testing.T) {
	tests := []struct {
		name          string
		envVars       map[string]string
		testURL       string
		expectedProxy string
	}{
		{
			name: "external_url_with_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:       "https://ec2.amazonaws.com",
			expectedProxy: "http://example-proxy:8080",
		},
		{
			name: "imds_ipv4_no_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:       "http://169.254.169.254/latest/user-data",
			expectedProxy: "",
		},
		{
			name: "imds_ipv6_no_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:       "http://[fd00:ec2::254]/latest/user-data",
			expectedProxy: "",
		},
		{
			name:          "no_env_vars",
			envVars:       map[string]string{},
			testURL:       "https://ec2.amazonaws.com",
			expectedProxy: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Testing the dynamicProxyFunc can invoke http.ProxyFromEnvironment() function
			// which freezes the proxy environment variables for the entire process due to sync.Once caching.
			// Hence, each test-case is run in a separate process to avoid caching.
			cmd := exec.Command("go", "test", "-run", "TestSingleProxyCase", "./")

			cmd.Env = os.Environ()
			cmd.Env = append(cmd.Env, fmt.Sprintf("TEST_NAME=%s", tt.name))
			cmd.Env = append(cmd.Env, fmt.Sprintf("TEST_URL=%s", tt.testURL))
			cmd.Env = append(cmd.Env, fmt.Sprintf("EXPECTED_PROXY=%s", tt.expectedProxy))

			// add the env variables for the actual proxy test
			for key, value := range tt.envVars {
				cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", key, value))
			}
			output, err := cmd.CombinedOutput()

			if err != nil {
				t.Errorf("Test %s failed: %v\nOutput: %s", tt.name, err, string(output))
			}
		})
	}
}

func TestSingleProxyCase(t *testing.T) {
	testName := os.Getenv("TEST_NAME")
	if testName == "" {
		t.Skip("Not a subprocess test")
	}

	testURL := os.Getenv("TEST_URL")
	expectedProxy := os.Getenv("EXPECTED_PROXY")

	req, _ := http.NewRequest("GET", testURL, nil)
	proxyURL, err := dynamicProxyFunc(req)

	if err != nil {
		t.Fatalf("dynamicProxyFunc returned error: %v", err)
	}

	var actualProxy string
	if proxyURL != nil {
		actualProxy = proxyURL.String()
	}

	assert.Equal(t, expectedProxy, actualProxy)
}
