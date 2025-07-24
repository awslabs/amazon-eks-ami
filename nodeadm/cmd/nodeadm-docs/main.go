package main

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/cmd/nodeadm-docs/maxpods"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
)

func main() {
	flaggy.SetName("nodeadm-docs")
	flaggy.SetDescription("Use nodeadm internals to generate supplementary information for docs")
	flaggy.DefaultParser.ShowHelpOnUnexpected = true

	opts := cli.NewGlobalOptions()

	cmds := []cli.Command{
		maxpods.NewMaxPodsCommand(),
	}

	for _, cmd := range cmds {
		flaggy.AttachSubcommand(cmd.Flaggy(), 1)
	}
	flaggy.Parse()

	log := cli.NewLogger(opts)

	for _, cmd := range cmds {
		if cmd.Flaggy().Used {
			err := cmd.Run(log, opts)
			if err != nil {
				log.Fatal("Command failed", zap.Error(err))
			}
			return
		}
	}
	flaggy.ShowHelpAndExit("No command specified")
}
