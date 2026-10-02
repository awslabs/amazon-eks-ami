package system

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

// os-release(5): read /etc/os-release, falling back to /usr/lib/os-release.
// see: https://www.freedesktop.org/software/systemd/man/latest/os-release.html
var osReleasePaths = []string{"/etc/os-release", "/usr/lib/os-release"}

// GetOSDistro identifies the host OS from os-release. It fails rather than
// defaulting, so an unsupported or unreadable host stops nodeadm loudly and fails conformance tests early.
func GetOSDistro(fsys FileSystem) (api.OSDistro, error) {
	data, path, err := readOSRelease(fsys)
	if err != nil {
		return "", err
	}
	fields := parseOSRelease(data)
	id, versionID := fields["ID"], fields["VERSION_ID"]
	if id == "amzn" {
		switch versionID {
		case "2023":
			return api.OSDistroAL2023, nil
		case "2027":
			return api.OSDistroAL2027, nil
		}
	}
	return "", fmt.Errorf("unsupported OS in %s: ID=%q VERSION_ID=%q (want amzn 2023 or 2027)", path, id, versionID)
}

func readOSRelease(fsys FileSystem) ([]byte, string, error) {
	for _, path := range osReleasePaths {
		data, err := fsys.ReadFile(path)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		return data, path, err
	}
	return nil, "", fmt.Errorf("no os-release file found at %v", osReleasePaths)
}

// parseOSRelease reads the newline-separated KEY=VALUE assignments, where a
// value may be wrapped in single or double quotes.
func parseOSRelease(data []byte) map[string]string {
	fields := map[string]string{}
	scanner := bufio.NewScanner(bytes.NewReader(data))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		if len(value) >= 2 && (value[0] == '"' || value[0] == '\'') && value[len(value)-1] == value[0] {
			value = value[1 : len(value)-1]
		}
		fields[key] = value
	}
	return fields
}
