package kubelet

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/stretchr/testify/assert"
)

func TestNvidiaGPULabel(t *testing.T) {
	tests := []struct {
		name          string
		files         map[string]string
		expectedValue string
		expectedOk    bool
	}{
		{
			name: "nvidia gpu present",
			files: map[string]string{
				"/sys/bus/pci/devices/0000:00:1e.0/vendor": "0x10de",
			},
			expectedValue: "true",
			expectedOk:    true,
		},
		{
			name: "no nvidia gpu",
			files: map[string]string{
				"/sys/bus/pci/devices/0000:00:1e.0/vendor": "0x1234",
			},
			expectedValue: "",
			expectedOk:    false,
		},
		{
			name: "no files at all",
			files: map[string]string{
				"/sys/bus/pci/devices/": system.EmptyDirectoryMarker,
			},
			expectedValue: "",
			expectedOk:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			label := NvidiaGPULabel{fs: system.FakeFileSystem{Files: tt.files}}
			value, ok, err := label.Get()
			assert.NoError(t, err)
			assert.Equal(t, tt.expectedValue, value)
			assert.Equal(t, tt.expectedOk, ok)
		})
	}
}
