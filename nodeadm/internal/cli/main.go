package cli

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type Main struct {
	Name           string
	Description    string
	AdditionalHelp string
	Commands       []Command
}

func (m *Main) Run() {
	opts := NewGlobalOptions()

	flaggy.SetName(m.Name)
	flaggy.SetDescription(m.Description)
	if m.AdditionalHelp != "" {
		flaggy.DefaultParser.AdditionalHelpPrepend = "\n" + m.AdditionalHelp
	}
	flaggy.DefaultParser.ShowHelpOnUnexpected = true

	for _, cmd := range m.Commands {
		flaggy.AttachSubcommand(cmd.Flaggy(), 1)
	}
	flaggy.Parse()
	log := NewLogger(opts)

	for _, cmd := range m.Commands {
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
