package runtime

import (
	"context"
	"fmt"
	"os"

	awsimds "github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
)

type ecrUriCmd struct {
	cmd    *flaggy.Subcommand
	region string
}

func NewEcrUriCommand() cli.Command {
	c := ecrUriCmd{
		cmd: flaggy.NewSubcommand("ecr-uri"),
	}
	c.cmd.Description = "Verify configuration"
	c.cmd.String(&c.region, "r", "region", "the region to check the ECR URI for")
	return &c
}

func (c *ecrUriCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *ecrUriCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	if c.region == "" {
		regionResponse, err := imds.Client.GetRegion(context.Background(), &awsimds.GetRegionInput{})
		if err != nil {
			return err
		}
		c.region = regionResponse.Region
		fmt.Fprintf(os.Stderr, "detected region using IMDS: %s", c.region)
	}
	registry, err := ecr.GetEKSRegistry(c.region)
	if err != nil {
		return err
	}
	fmt.Println(registry)
	return nil
}
