package main

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func main() {
	m := cli.Main{
		Name:           "nodeadm-aux",
		Description:    "Supporting tools for systems using nodeadm",
		AdditionalHelp: "WARNING: There is no command-line stability guarantee!",
		Commands: []cli.Command{
			newUdevNetManagedByCommand(),
		},
	}
	m.Run()
}
