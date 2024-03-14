package install

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/ecr"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/install"
)

func NewInstallCommand() cli.Command {
	install := installCmd{}
	install.cmd = flaggy.NewSubcommand("install")
	install.cmd.Description = "Install components required to join an EKS cluster"
	install.cmd.String(&install.kubernetesVersion, "k", "kubernetes-version", "the kubernetes major and minor version to install")
	return &install
}

type installCmd struct {
	cmd               *flaggy.Subcommand
	kubernetesVersion string
}

func (c *installCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *installCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	log.Info("Checking user is root..")
	root, err := cli.IsRunningAsRoot()
	if err != nil {
		return err
	} else if !root {
		return cli.ErrMustRunAsRoot
	}

	log.Info("Loading configuration..", zap.String("configSource", opts.ConfigSource))
	provider, err := configprovider.BuildConfigProvider(opts.ConfigSource)
	if err != nil {
		return err
	}
	nodeConfig, err := provider.Provide()
	if err != nil {
		return err
	}
	log.Info("Loaded configuration", zap.Reflect("config", nodeConfig))

	log.Info("Enriching configuration..")
	if err := enrichConfig(log, nodeConfig); err != nil {
		return err
	}

	zap.L().Info("Validating configuration..")
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}

	log.Info("Loading configuration")
	awsCfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion("us-west-2"))
	if err != nil {
		return err
	}

	log.Info("Installing components")
	return install.Install(context.Background(), c.kubernetesVersion, *nodeConfig, awsCfg)
}

// Various initializations and verifications of the NodeConfig and
// perform in-place updates when allowed by the user
func enrichConfig(log *zap.Logger, cfg *api.NodeConfig) error {
	var instanceDetails *api.InstanceDetails
	instanceDetails = &api.InstanceDetails{
		Region: cfg.Spec.Hybrid.Region,
	}
	cfg.Status.Instance = *instanceDetails
	log.Info("Instance details populated", zap.Reflect("details", instanceDetails))

	registry := ecr.GetHybridRegistry(instanceDetails.Region)
	cfg.Status.Defaults = api.DefaultOptions{
		SandboxImage: registry.GetSandboxImage(),
	}
	return nil
}
