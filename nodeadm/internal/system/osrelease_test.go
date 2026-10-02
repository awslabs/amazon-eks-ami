package system

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

const al2027OSRelease = `NAME="Amazon Linux"
VERSION="2027"
ID="amzn"
ID_LIKE="fedora"
VERSION_ID="2027"
PLATFORM_ID="platform:al2027"
`

func TestGetOSDistro(t *testing.T) {
	tests := []struct {
		name     string
		files    map[string]string
		expected api.OSDistro
		errMsg   string
	}{
		{
			name:     "al2027",
			files:    map[string]string{"/etc/os-release": al2027OSRelease},
			expected: api.OSDistroAL2027,
		},
		{
			name:     "al2023 with unquoted values and comments",
			files:    map[string]string{"/etc/os-release": "# comment\nID=amzn\nVERSION_ID=2023\n"},
			expected: api.OSDistroAL2023,
		},
		{
			name:     "single-quoted values",
			files:    map[string]string{"/etc/os-release": "ID='amzn'\nVERSION_ID='2027'\n"},
			expected: api.OSDistroAL2027,
		},
		{
			name:     "falls back to /usr/lib/os-release",
			files:    map[string]string{"/usr/lib/os-release": al2027OSRelease},
			expected: api.OSDistroAL2027,
		},
		{
			name:     "/etc/os-release takes precedence",
			files:    map[string]string{"/etc/os-release": "ID=amzn\nVERSION_ID=2023\n", "/usr/lib/os-release": al2027OSRelease},
			expected: api.OSDistroAL2023,
		},
		{
			name:   "no os-release file",
			files:  map[string]string{},
			errMsg: "no os-release file found",
		},
		{
			name:   "unsupported amzn version",
			files:  map[string]string{"/etc/os-release": "ID=amzn\nVERSION_ID=2\n"},
			errMsg: `unsupported OS in /etc/os-release: ID="amzn" VERSION_ID="2"`,
		},
		{
			name:   "other distro",
			files:  map[string]string{"/etc/os-release": "ID=ubuntu\nVERSION_ID=\"24.04\"\n"},
			errMsg: `ID="ubuntu" VERSION_ID="24.04"`,
		},
		{
			name:   "empty file",
			files:  map[string]string{"/etc/os-release": ""},
			errMsg: `ID="" VERSION_ID=""`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			distro, err := GetOSDistro(FakeFileSystem{Files: tt.files})
			if tt.errMsg != "" {
				assert.ErrorContains(t, err, tt.errMsg)
				assert.Empty(t, distro)
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, distro)
		})
	}
}
