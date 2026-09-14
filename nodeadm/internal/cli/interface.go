package cli

import (
	"context"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type Command interface {
	Run(ctx context.Context, log *zap.Logger, opts *GlobalOptions) error
	Flaggy() *flaggy.Subcommand
}
