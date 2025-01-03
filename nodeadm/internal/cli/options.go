package cli

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

var DefaultConfigSources = []string{
	"imds://user-data",
	// TODO: consider adding file:///etc/eks/nodeadm.d/. this is a breaking
	// change, but users can override the default if it does not work for them.
}

type GlobalOptions struct {
	DevelopmentMode bool
}

func NewGlobalOptions() *GlobalOptions {
	opts := GlobalOptions{
		// we do not set a default ConfigSources here, to work around the additive nature of StringSlice flags
		// callers should fall back to DefaultConfigSources when the user has provided no input
		DevelopmentMode: false,
	}
	flaggy.Bool(&opts.DevelopmentMode, "d", "development", "Enable development mode for logging.")
	return &opts
}

func RegisterFlagConfigOutput(c *flaggy.Subcommand, configOutput *string) {
	c.String(configOutput, "o", "config-output", "File path to write the final resolved config to. JSON encoding is used.")
}

// RegisterFlagConfigSources maps a command-line flag for config sources to the specified string slice for the specified command.
// No default value is set for this flag, because StringSlice flags are additive.
// Callers should fall back to DefaultConfigSources if the user has provided no input.
// ResolveConfigSources can be used for this, for convenience.
func RegisterFlagConfigSources(c *flaggy.Subcommand, configSources *[]string) {
	c.StringSlice(configSources, "c", "config-source", "Source(s) of node configuration. The format is a URI with supported schemes: [imds, file]. Sources will be evaluated in the order specified.")
}

// ResolveConfigSources returns the default config sources if the specified slice is empty.
func ResolveConfigSources(configSources []string) []string {
	if len(configSources) > 0 {
		return configSources
	}
	zap.L().Info("Using default config sources...")
	return DefaultConfigSources
}
