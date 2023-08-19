package config

import "github.com/awslabs/amazon-eks-ami/bootstrap/cmd"

func NewConfigCommand() cmd.Command {
	container := cmd.NewCommandContainer("config", "Manage bootstrap configuration")
	container.AddCommand(NewCheckCommand())
	return container.AsCommand()
}
