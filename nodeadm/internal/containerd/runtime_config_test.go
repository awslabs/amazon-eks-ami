package containerd

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestApplyInstanceTypeMixins(t *testing.T) {

	var nvidiaExpectedOutput = instanceOptions{RuntimeName: "nvidia", RuntimeBinaryName: "/usr/bin/nvidia-container-runtime"}
	var neuronExpectedOutput = instanceOptions{RuntimeName: "runc", RuntimeBinaryName: "/usr/sbin/runc"}
	var nonAcceleratedExpectedOutput = instanceOptions{RuntimeName: "runc", RuntimeBinaryName: "/usr/sbin/runc"}

	var tests = []struct {
		name           string
		instanceType   string
		expectedOutput instanceOptions
	}{
		{name: "nvidia_test", instanceType: "p5.xlarge", expectedOutput: nvidiaExpectedOutput},
		{name: "neuron_test", instanceType: "inf2.xlarge", expectedOutput: neuronExpectedOutput},
		// non accelerated instance
		{name: "non_accelerated_test", instanceType: "m5.xlarge", expectedOutput: nonAcceleratedExpectedOutput},
	}
	for _, test := range tests {
		expected := applyInstanceTypeMixins(test.instanceType)

		if !reflect.DeepEqual(expected, test.expectedOutput) {
			t.Fatalf("unexpected output in test case %s: %s, expecting: %s", test.name, expected, test.expectedOutput)
		}
	}
}

func TestPCIeDetection(t *testing.T) {
	t.Run("Matches", func(t *testing.T) {
		mixin := instanceTypeMixin{
			pcieDevicesPath: filepath.Join(t.TempDir(), "devices"),
			pcieDriverName:  "nvidia",
		}
		assert.NoError(t, os.WriteFile(mixin.pcieDevicesPath, []byte("nvidia"), 0777))
		assert.True(t, mixin.matches("x.x"))
		assert.True(t, mixin.matchesPCIeDriver())
	})
	t.Run("NotMatchesBecauseDifferent", func(t *testing.T) {
		mixin := instanceTypeMixin{
			pcieDevicesPath: filepath.Join(t.TempDir(), "devices"),
			pcieDriverName:  "nvidia",
		}
		assert.NoError(t, os.WriteFile(mixin.pcieDevicesPath, []byte("nvme"), 0777))
		assert.False(t, mixin.matches("x.x"))
		assert.False(t, mixin.matchesPCIeDriver())
	})
	t.Run("NotMatchesBecauseMissing", func(t *testing.T) {
		mixin := instanceTypeMixin{}
		assert.False(t, mixin.matches("x.x"))
		assert.False(t, mixin.matchesPCIeDriver())
	})
}
