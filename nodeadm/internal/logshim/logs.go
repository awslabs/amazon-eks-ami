package logshim

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
)

const logCollectorScript = "/etc/eks/log-collector-script/eks-log-collector.sh"
const baseOutputDirectory = "/etc/eks/nodeadm/"

type LogCollector interface {
	Collect() (string, error)
	GetDataPath() (string, error)
}

type logCollector struct {
	outputDirectory string
}

func NewLogCollector(identifier string) LogCollector {
	return logCollector{
		outputDirectory: filepath.Join(baseOutputDirectory, identifier),
	}
}

func (l logCollector) Collect() (string, error) {
	var out strings.Builder
	var errString strings.Builder

	cmd := exec.Command(logCollectorScript, "--output_dir", l.outputDirectory)
	cmd.Stdout = &out
	cmd.Stderr = &errString

	err := cmd.Run()
	if err != nil {
		return "", fmt.Errorf("%v: %s", err, errString.String())
	}

	return out.String(), nil
}

func (l logCollector) GetDataPath() (string, error) {
	pathGlob := filepath.Join(l.outputDirectory, "eks_*")
	globbedPath, err := filepath.Glob(pathGlob)
	if err != nil || len(globbedPath) == 0 {
		return "", fmt.Errorf("failed to find log data path: %v", err)
	}
	return globbedPath[0], nil
}
