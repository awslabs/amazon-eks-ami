package config

import (
	"fmt"

	"github.com/awslabs/amazon-eks-ami/bootstrap/cmd"
	"github.com/awslabs/amazon-eks-ami/bootstrap/pkg/config"
	"github.com/integrii/flaggy"
	"sigs.k8s.io/yaml"
)

type fileCmd struct {
	cmd  *flaggy.Subcommand
	path *string
}

func NewCheckCommand() cmd.Command {
	cmd := flaggy.NewSubcommand("check")
	cmd.Description = "Verify a configuration file"
	var path string
	cmd.AddPositionalValue(&path, "path", 1, true, "Path to configuration file")
	return &fileCmd{
		cmd:  cmd,
		path: &path,
	}
}

func (c *fileCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *fileCmd) Run() error {
	bootstrapConfig, err := config.LoadFromFile(*c.path)
	if err != nil {
		return err
	}
	yamlBytes, err := yaml.Marshal(&bootstrapConfig)
	if err != nil {
		return err
	}
	fmt.Printf("%s", string(yamlBytes))
	return nil
}
