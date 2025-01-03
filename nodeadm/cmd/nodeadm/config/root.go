package config

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func NewConfigCommand() cli.Command {
	container := cli.NewCommandContainer("config", "Manage configuration")
	container.AddCommand(NewCheckCommand())
	container.AddCommand(NewDumpCommand())
	return container.AsCommand()
}
