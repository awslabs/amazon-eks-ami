package system

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetOnlineMemory(t *testing.T) {
	tests := []struct {
		name     string
		files    map[string]string
		expected int64
	}{
		{
			name: "single online block",
			files: map[string]string{
				"/sys/devices/system/memory/block_size_bytes": "8000000",
				"/sys/devices/system/memory/memory0/online":   "1",
			},
			expected: 0x8000000,
		},
		{
			name: "multiple blocks mixed online status",
			files: map[string]string{
				"/sys/devices/system/memory/block_size_bytes": "8000000",
				"/sys/devices/system/memory/memory0/online":   "1",
				"/sys/devices/system/memory/memory1/online":   "0",
				"/sys/devices/system/memory/memory2/online":   "1",
			},
			expected: 0x8000000 * 2,
		},
		{
			name: "no online blocks",
			files: map[string]string{
				"/sys/devices/system/memory/block_size_bytes": "8000000",
				"/sys/devices/system/memory/memory0/online":   "0",
			},
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewResources(FakeFileSystem{Files: tt.files})
			mem, err := r.GetOnlineMemory()
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, mem)
		})
	}
}

func TestGetMilliNumCores_FallbackToCPUCount(t *testing.T) {
	files := map[string]string{
		"/sys/devices/system/cpu/cpu0": EmptyDirectoryMarker,
		"/sys/devices/system/cpu/cpu1": EmptyDirectoryMarker,
		"/sys/devices/system/cpu/cpu2": EmptyDirectoryMarker,
		"/sys/devices/system/cpu/cpu3": EmptyDirectoryMarker,
	}
	r := NewResources(FakeFileSystem{Files: files})
	cores, err := r.GetMilliNumCores()
	assert.NoError(t, err)
	assert.Equal(t, 4000, cores)
}

func TestGetMilliNumCores_WithNodeTopology(t *testing.T) {
	tests := []struct {
		name     string
		files    map[string]string
		expected int
	}{
		{
			name: "single node with four cpus",
			files: map[string]string{
				"/sys/devices/system/node/node0/cpu0": EmptyDirectoryMarker,
				"/sys/devices/system/node/node0/cpu1": EmptyDirectoryMarker,
				"/sys/devices/system/node/node0/cpu2": EmptyDirectoryMarker,
				"/sys/devices/system/node/node0/cpu3": EmptyDirectoryMarker,
			},
			expected: 4000,
		},
		{
			name: "two nodes with two cpus each",
			files: map[string]string{
				"/sys/devices/system/node/node0/cpu0": EmptyDirectoryMarker,
				"/sys/devices/system/node/node0/cpu1": EmptyDirectoryMarker,
				"/sys/devices/system/node/node1/cpu2": EmptyDirectoryMarker,
				"/sys/devices/system/node/node1/cpu3": EmptyDirectoryMarker,
			},
			expected: 4000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewResources(FakeFileSystem{Files: tt.files})
			cores, err := r.GetMilliNumCores()
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, cores)
		})
	}
}

func TestGetMilliNumCores_OfflineCPUs(t *testing.T) {
	files := map[string]string{
		"/sys/devices/system/cpu/online":      "0,2-4,6",
		"/sys/devices/system/node/node0/cpu0": EmptyDirectoryMarker,
		"/sys/devices/system/node/node0/cpu1": EmptyDirectoryMarker,
		"/sys/devices/system/node/node1/cpu2": EmptyDirectoryMarker,
		"/sys/devices/system/node/node1/cpu3": EmptyDirectoryMarker,
		"/sys/devices/system/node/node2/cpu4": EmptyDirectoryMarker,
		"/sys/devices/system/node/node2/cpu5": EmptyDirectoryMarker,
		"/sys/devices/system/node/node3/cpu6": EmptyDirectoryMarker,
		"/sys/devices/system/node/node4/cpu7": EmptyDirectoryMarker,
	}
	r := NewResources(FakeFileSystem{Files: files})
	cores, err := r.GetMilliNumCores()
	assert.NoError(t, err)
	assert.Equal(t, 5000, cores)
}
