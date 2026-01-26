package system

import "testing"

func TestSystemdEscapePath(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"/", "-"},
		{"/foo//bar/baz/", "foo-bar-baz"},
		{"/dev/sda", "dev-sda"},
		{"/var/lib/kubelet", "var-lib-kubelet"},
		{"/var/lib/soci-snapshotter-grpc", "var-lib-soci\\x2dsnapshotter\\x2dgrpc"},
		{"/mnt/k8s-disks/0", "mnt-k8s\\x2ddisks-0"},
		{"/.hidden", "\\x2ehidden"},
		{"/foo.bar", "foo.bar"},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := systemdEscapePath(tt.input)
			if got != tt.expected {
				t.Errorf("systemdEscapePath(%q) = %q, want %q", tt.input, got, tt.expected)
			}
		})
	}
}

func TestSystemdEscapePathSpecialChars(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"/path with spaces", "path\\x20with\\x20spaces"},
		{"/path@special#chars", "path\\x40special\\x23chars"},
	}
	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := systemdEscapePath(tt.input)
			if got != tt.expected {
				t.Errorf("systemdEscapePath(%q) = %q, want %q", tt.input, got, tt.expected)
			}
		})
	}
}
