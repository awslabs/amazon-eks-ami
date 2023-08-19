package cmd

import "github.com/integrii/flaggy"

type Command interface {
	Run() error
	Flaggy() *flaggy.Subcommand
}
