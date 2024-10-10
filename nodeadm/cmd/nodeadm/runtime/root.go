package runtime

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func NewRuntimeCommand() cli.Command {
	container := cli.NewCommandContainer("runtime", "Runtime configuration utilities")
	container.AddCommand(NewEcrUriCommand())
	return container.AsCommand()
}
