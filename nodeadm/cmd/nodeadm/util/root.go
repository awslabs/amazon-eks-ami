package util

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func NewUtilCommand() cli.Command {
	container := cli.NewCommandContainer("util", "Utilities for node operation")
	container.AddCommand(NewNetworkInterfaceOwnerCommand())
	return container.AsCommand()
}
