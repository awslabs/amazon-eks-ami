package init

import (
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	featuregates "github.com/awslabs/amazon-eks-ami/nodeadm/internal/feature-gates"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

func NewInitCommand() cli.Command {
	init := initCmd{}
	init.cmd = flaggy.NewSubcommand("init")
	init.cmd.Bool(&init.skipConfigure, "sc", "skip-configure", "skip the daemon configuration step")
	init.cmd.Bool(&init.skipRun, "sr", "skip-run", "skip the daemon running step")
	init.cmd.Description = "Initialize this instance as a node in an EKS cluster"
	return &init
}

type initCmd struct {
	cmd           *flaggy.Subcommand
	skipConfigure bool
	skipRun       bool
}

func (c *initCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *initCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
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
	if err := enrichConfig(nodeConfig); err != nil {
		return err
	}

	zap.L().Info("Validating configuration..")
	if err := util.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}

	log.Info("Creating daemon manager..")
	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()

	log.Info("Setting up daemons..")
	daemons := []daemon.Daemon{
		containerd.NewContainerdDaemon(daemonManager),
		kubelet.NewKubeletDaemon(daemonManager),
	}

	if !c.skipConfigure {
		for _, daemon := range daemons {
			nameField := zap.String("name", daemon.Name())

			log.Info("Configuring daemon..", nameField)
			if err := daemon.Configure(nodeConfig); err != nil {
				return err
			}
			log.Info("Configured daemon", nameField)
		}
	}

	if !c.skipRun {
		for _, daemon := range daemons {
			nameField := zap.String("name", daemon.Name())

			log.Info("Ensuring daemon is running..", nameField)
			if err := daemon.EnsureRunning(); err != nil {
				return err
			}
			log.Info("Daemon is running", nameField)

			log.Info("Running post-launch tasks..", nameField)
			if err := daemon.PostLaunch(nodeConfig); err != nil {
				return err
			}
			log.Info("Finished post-launch tasks", nameField)
		}
	}

	return nil
}

// Various initializations and verifications of the NodeConfig and
// perform in-place updates when allowed by the user
func enrichConfig(cfg *api.NodeConfig) error {
	zap.L().Info("Fetching instance details..")
	instanceDetails, err := util.FetchInstanceDetails()
	if err != nil {
		return err
	}
	cfg.Status.Instance = *instanceDetails
	zap.L().Info("Instance details populated", zap.Reflect("details", instanceDetails))

	if featuregates.DefaultFalse(featuregates.DescribeClusterDetails, cfg.Spec.FeatureGates) {
		zap.L().Info("Populating cluster details using a describe-cluster call..")
		if err := featuregates.PopulateClusterDetails(cfg.Spec.Cluster.Name, cfg); err != nil {
			return err
		}
	}

	return nil
}
