package daemon

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func NewDaemonCommand() cli.Command {
	container := cli.NewCommandContainer("daemon", "Run a command as a daemon")
	container.AddCommand(NewConfigCheckCommand())
	return container.AsCommand()
}
