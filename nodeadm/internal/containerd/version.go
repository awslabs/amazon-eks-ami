package containerd

import (
	"errors"
	"os"
	"os/exec"
	"regexp"

	"go.uber.org/zap"
)

const (
	containerdVersionFile = "/etc/eks/containerd-version.txt"
)

func GetContainerdVersion() (string, error) {
	rawVersion, err := GetContainerdVersionRaw()
	if err != nil {
		return "", err
	}
	semVerRegex := regexp.MustCompile(`[0-9]+\.[0-9]+.[0-9]+`)
	return semVerRegex.FindString(string(rawVersion)), nil
}

func GetContainerdVersionRaw() ([]byte, error) {
	if _, err := os.Stat(containerdVersionFile); errors.Is(err, os.ErrNotExist) {
		zap.L().Info("Reading containerd version from executable")
		return exec.Command("containerd", "--version").Output()
	} else if err != nil {
		return nil, err
	}
	zap.L().Info("Reading containerd version from file", zap.String("path", containerdVersionFile))
	return os.ReadFile(containerdVersionFile)
}
