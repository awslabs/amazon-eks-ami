package main

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/cmd/nodeadm/config"
	initcmd "github.com/awslabs/amazon-eks-ami/nodeadm/cmd/nodeadm/init"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func main() {
	m := cli.Main{
		Name:           "nodeadm",
		Description:    "From zero to Node faster than you can say Elastic Kubernetes Service",
		AdditionalHelp: "http://github.com/awslabs/amazon-eks-ami/nodeadm",
		Commands: []cli.Command{
			config.NewConfigCommand(),
			initcmd.NewInitCommand(),
		},
	}
	m.Run()
}
