package main

import (
	"log"

	"github.com/awslabs/amazon-eks-ami/bootstrap/cmd"
	"github.com/awslabs/amazon-eks-ami/bootstrap/cmd/config"
	"github.com/integrii/flaggy"
)

var version = "0.0.0-dev"

func main() {
	flaggy.SetName("bootstrap")
	flaggy.SetDescription("From zero to Node faster than you can say Elastic Kubernetes Service")
	flaggy.SetVersion(version)
	flaggy.DefaultParser.ShowHelpOnUnexpected = true
	flaggy.DefaultParser.AdditionalHelpPrepend = "\nhttp://github.com/awslabs/amazon-eks-ami/bootstrap"
	var cmds []cmd.Command
	cmds = append(cmds, config.NewConfigCommand())
	for _, cmd := range cmds {
		flaggy.AttachSubcommand(cmd.Flaggy(), 1)
	}
	flaggy.Parse()
	for _, cmd := range cmds {
		if cmd.Flaggy().Used {
			err := cmd.Run()
			if err != nil {
				log.Fatal(err)
			}
			return
		}
	}
	flaggy.ShowHelpAndExit("no command specified")
}
