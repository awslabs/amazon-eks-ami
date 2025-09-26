package instancedata

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const SystemdNetworkdDaemonName = "systemd-networkd"

type instanceDataCmd struct {
	cmd *flaggy.Subcommand
}

func NewInstanceDataCommand() cli.Command {
	cmd := flaggy.NewSubcommand("instance-data")
	cmd.Description = "Generate instance data for all describable instance types in JSON lines syntax."
	return &instanceDataCmd{
		cmd: cmd,
	}
}

func (c *instanceDataCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *instanceDataCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	ctx := context.TODO()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return err
	}
	instanceTypeInfos, err := util.GetGlobalSortedInstanceTypeInfo(ctx, cfg)
	if err != nil {
		return err
	}
	for _, instanceTypeInfo := range instanceTypeInfos {
		infoBytes, err := json.Marshal(instanceTypeInfo)
		if err != nil {
			return err
		}
		fmt.Println(string(infoBytes))
	}
	return nil
}
