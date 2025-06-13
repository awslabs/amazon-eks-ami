package kubelet

import (
	"errors"
	"os"
	"os/exec"
	"regexp"

	"go.uber.org/zap"
)

func GetKubeletVersion() (string, error) {
	rawVersion, err := GetKubeletVersionRaw()
	if err != nil {
		return "", err
	}
	version := parseSemVer(string(rawVersion))
	return version, nil
}

const kubeletVersionFile = "/etc/eks/kubelet-version.txt"

func GetKubeletVersionRaw() ([]byte, error) {
	if _, err := os.Stat(kubeletVersionFile); errors.Is(err, os.ErrNotExist) {
		zap.L().Info("Reading kubelet version from executable")
		return exec.Command("kubelet", "--version").Output()
	} else if err != nil {
		return nil, err
	}
	zap.L().Info("Reading kubelet version from file", zap.String("path", kubeletVersionFile))
	return os.ReadFile(kubeletVersionFile)
}

var semVerRegex = regexp.MustCompile(`v[0-9]+\.[0-9]+.[0-9]+`)

func parseSemVer(rawVersion string) string {
	return semVerRegex.FindString(rawVersion)
}
