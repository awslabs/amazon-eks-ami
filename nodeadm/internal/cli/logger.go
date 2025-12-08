package cli

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func NewLogger(opts *GlobalOptions) *zap.Logger {
	var logger *zap.Logger
	var err error
	if opts.DevelopmentMode {
		logger, err = zap.NewDevelopment()
	} else {
		config := zap.NewProductionConfig()
		config.DisableStacktrace = true
		config.Encoding = "console"
		config.EncoderConfig.TimeKey = ""
		config.EncoderConfig.ConsoleSeparator = " "
		config.EncoderConfig.EncodeCaller = zapcore.ShortCallerEncoder
		logger, err = config.Build()
	}
	if err != nil {
		panic(err)
	}
	zap.ReplaceGlobals(logger)
	return logger
}
