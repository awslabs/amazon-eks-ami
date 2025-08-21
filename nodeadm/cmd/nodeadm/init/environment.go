package init

import (
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

	// Write variables to /etc/environment in append mode
	file, err := os.OpenFile(etcEnvironmentPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open /etc/environment: %w", err)
	}
	defer file.Close()

	fmt.Fprintln(file, "")
	fmt.Fprintln(file, nodeadmMarkerStart)

	// Set environment variables in current process and write to file
	for key, value := range instanceOpts.Environment {
		os.Setenv(key, value)
		fmt.Fprintf(file, "%s=%s\n", key, value)
		log.Info("Set environment variable", zap.String("key", key), zap.String("value", value))
	}
	fmt.Fprintln(file, nodeadmMarkerEnd)
	return nil
}
