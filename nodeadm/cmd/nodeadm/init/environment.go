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

	// Read existing /etc/environment content
	existingContent, err := readEtcEnvironment()
	if err != nil {
		return fmt.Errorf("failed to read /etc/environment: %w", err)
	}

	// Remove any existing nodeadm section
	cleanedContent := removeNodeadmSection(existingContent)

	// Add nodeadm environment variables
	newContent := addNodeadmSection(cleanedContent, instanceOpts.Environment)

	// Write the updated content
	if err := writeEtcEnvironment(newContent); err != nil {
		return fmt.Errorf("failed to write /etc/environment: %w", err)
	}

	// Also set environment variables in current process for immediate use
	for key, value := range instanceOpts.Environment {
		os.Setenv(key, value)
		log.Info("Set environment variable", zap.String("key", key), zap.String("value", value))
	}

	log.Info("Successfully configured system environment variables")
	return nil
}

func readEtcEnvironment() ([]string, error) {
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

// Removes any existing nodeadm environment section/
// This is to ensure that if nodeadm is manually run on an already running node
// it cleans up any already existing nodeadm related environment variables and
// does not introduce diplicate environment keys with conflicting values
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

func addNodeadmSection(existingLines []string, envVars map[string]string) []string {
	result := existingLines
	result = append(result, "")
	result = append(result, nodeadmMarkerStart)

	// sorting order of the variables for consistency
	keys := make([]string, 0, len(envVars))
	for key := range envVars {
		keys = append(keys, key)
	}

	for i := 0; i < len(keys); i++ {
		for j := i + 1; j < len(keys); j++ {
			if keys[i] > keys[j] {
				keys[i], keys[j] = keys[j], keys[i]
			}
		}
	}

	for _, key := range keys {
		value := envVars[key]
		result = append(result, fmt.Sprintf("%s=%s", key, value))
	}

	result = append(result, nodeadmMarkerEnd)
	return result
}

func writeEtcEnvironment(lines []string) error {
	file, err := os.Create(etcEnvironmentPath)
	if err != nil {
		return err
	}
	defer file.Close()

	for _, line := range lines {
		if _, err := fmt.Fprintln(file, line); err != nil {
			return err
		}
	}

	return nil
}
