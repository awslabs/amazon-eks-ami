package main

import (
	boothook "github.com/awslabs/amazon-eks-ami/nodeadm/cmd/nodeadm-internal/boot-hook"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func main() {
	m := cli.Main{
		Name:           "nodeadm-internal",
		Description:    "Supporting tools for systems using nodeadm",
		AdditionalHelp: "WARNING: There is no command-line stability guarantee!",
		Commands: []cli.Command{
			boothook.NewBootHookCommand(),
		},
	}
	m.Run()
}
