package imds

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"testing"
)

func TestDynamicProxyFuncBehavior(t *testing.T) {
	tests := []struct {
		name           string
		envVars        map[string]string
		testURL        string
		shouldUseProxy bool
		expectedProxy  string
	}{
		{
			name: "external_url_with_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:        "https://ec2.amazonaws.com",
			shouldUseProxy: true,
			expectedProxy:  "http://example-proxy:8080",
		},
		{
			name: "imds_ipv4_no_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:        "http://169.254.169.254/latest/user-data",
			shouldUseProxy: false,
		},
		{
			name: "imds_ipv6_no_proxy",
			envVars: map[string]string{
				"HTTPS_PROXY": "http://example-proxy:8080",
			},
			testURL:        "http://[fd00:ec2::254]/latest/user-data",
			shouldUseProxy: false,
		},
		{
			name:           "no_env_vars",
			envVars:        map[string]string{},
			testURL:        "https://ec2.amazonaws.com",
			shouldUseProxy: false,
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
			cmd.Env = append(cmd.Env, fmt.Sprintf("SHOULD_USE_PROXY=%t", tt.shouldUseProxy))
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
	shouldUseProxy := os.Getenv("SHOULD_USE_PROXY") == "true"
	expectedProxy := os.Getenv("EXPECTED_PROXY")

	req, _ := http.NewRequest("GET", testURL, nil)
	proxyURL, err := dynamicProxyFunc(req)

	if err != nil {
		t.Fatalf("dynamicProxyFunc returned error: %v", err)
	}

	if shouldUseProxy {
		if proxyURL == nil {
			t.Errorf("Should detect proxy for %s", testURL)
		} else if proxyURL.String() != expectedProxy {
			t.Errorf("Expected proxy '%s', got '%s'", expectedProxy, proxyURL.String())
		}
	} else {
		if proxyURL != nil {
			t.Errorf("Should NOT use proxy for %s, got: %s", testURL, proxyURL.String())
		}
	}
}
