package init

import (
	"bufio"
	"fmt"
	"os"

	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

const (
	etcEnvironmentPath = "/etc/environment"
	nodeadmMarkerStart = "# nodeadm environment variables - start"
	nodeadmMarkerEnd   = "# nodeadm environment variables - end"
)

// making environment variables available system-wide to all processes and services.
func writeSystemEnvironmentVariables(log *zap.Logger, instanceOpts api.InstanceOptions) error {
	if len(instanceOpts.Environment) == 0 {
		log.Info("No environment variables to configure")
		return nil
	}

	log.Info("Writing environment variables to /etc/environment", zap.Int("count", len(instanceOpts.Environment)))

	lines, err := readEnvironmentFile()
	if err != nil {
		return fmt.Errorf("failed to read /etc/environment: %w", err)
	}

	cleanedLines := removeNodeadmSection(lines)
	updatedLines := addNodeadmSection(cleanedLines, instanceOpts.Environment)

	if err := writeEnvironmentFile(updatedLines); err != nil {
		return fmt.Errorf("failed to write /etc/environment: %w", err)
	}

	for key, value := range instanceOpts.Environment {
		if err := os.Setenv(key, value); err != nil {
			log.Warn("Failed to set environment variable", zap.String("key", key), zap.Error(err))
		}
		log.Info("Set environment variable", zap.String("key", key), zap.String("value", value))
	}

	return nil
}

func readEnvironmentFile() ([]string, error) {
	file, err := os.Open(etcEnvironmentPath)
	if os.IsNotExist(err) {
		return []string{}, nil
	}
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	return lines, scanner.Err()
}

func removeNodeadmSection(lines []string) []string {
	var result []string
	inNodeadmSection := false

	for _, line := range lines {
		if line == nodeadmMarkerStart {
			inNodeadmSection = true
			continue
		}
		if line == nodeadmMarkerEnd {
			inNodeadmSection = false
			continue
		}
		if !inNodeadmSection {
			result = append(result, line)
		}
	}
	return result
}

func addNodeadmSection(lines []string, envVars map[string]string) []string {
	result := make([]string, len(lines))
	copy(result, lines)

	if len(result) > 0 && result[len(result)-1] != "" {
		result = append(result, "")
	}

	result = append(result, nodeadmMarkerStart)

	for key, value := range envVars {
		result = append(result, fmt.Sprintf("%s=%s", key, value))
	}

	result = append(result, nodeadmMarkerEnd)
	return result
}

func writeEnvironmentFile(lines []string) error {
	file, err := os.Create(etcEnvironmentPath)
	if err != nil {
		return err
	}
	defer file.Close()

	if err := file.Chmod(0600); err != nil {
		return err
	}

	for _, line := range lines {
		if _, err := fmt.Fprintln(file, line); err != nil {
			return err
		}
	}
	return nil
}
