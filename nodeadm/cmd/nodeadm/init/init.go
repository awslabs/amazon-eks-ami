package init

import (
	"fmt"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	featuregates "github.com/awslabs/amazon-eks-ami/nodeadm/internal/feature-gates"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
	localdisks "github.com/awslabs/amazon-eks-ami/nodeadm/internal/local-disks"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

func NewInitCommand() cli.Command {
	cmd := flaggy.NewSubcommand("init")
	cmd.Description = "Initialize this instance as a node in an EKS cluster"
	return &initCmd{
		cmd: cmd,
	}
}

type initCmd struct {
	cmd *flaggy.Subcommand
}

func (c *initCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *initCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	root, err := cli.IsRunningAsRoot()
	if err != nil {
		return err
	}
	if !root {
		return cli.ErrMustRunAsRoot
	}
	log.Info("Loading configuration..", zap.String("configSource", opts.ConfigSource))
	provider, err := configprovider.BuildConfigProvider(opts.ConfigSource)
	if err != nil {
		return err
	}

	config, err := provider.Provide()
	if err != nil {
		return err
	}
	log.Info("Loaded configuration", zap.Reflect("config", config))

	log.Info("Enriching configuration..")
	if err := enrichConfig(log, config); err != nil {
		return err
	}
	log.Info("Enriched configuration")

	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()

	daemons := createDaemonMap(
		localdisks.NewLocalDisksDaemon(daemonManager),
		containerd.NewContainerdDaemon(daemonManager),
		kubelet.NewKubeletDaemon(daemonManager),
	)

	daemon.ConfigureDependencies(kubelet.KubeletDaemonName,
		containerd.ContainerdDaemonName,
	)

	for _, daemon := range daemons {
		nameField := zap.String("name", daemon.Name())

		log.Info("Configuring daemon..", nameField)
		if err := daemon.Configure(config); err != nil {
			return err
		}
		log.Info("Configured daemon", nameField)
	}

	for _, daemon := range daemons {
		nameField := zap.String("name", daemon.Name())

		log.Info("Ensuring daemon is running..", nameField)
		if err := daemon.EnsureRunning(); err != nil {
			return err
		}
		log.Info("Daemon is running", nameField)

		log.Info("Running post-launch tasks..", nameField)
		if err := daemon.PostLaunch(config); err != nil {
			return err
		}
		log.Info("Finished post-launch tasks", nameField)
	}

	return nil
}

// Cleaner daemon definitions
func createDaemonMap(daemons ...daemon.Daemon) map[string]daemon.Daemon {
	daemonMap := make(map[string]daemon.Daemon, len(daemons))
	for _, daemon := range daemons {
		daemonMap[daemon.Name()] = daemon
	}
	return daemonMap
}

// Various initializations and verifications of the NodeConfig and
// perform in-place updates when allowed by the user
func enrichConfig(log *zap.Logger, cfg *api.NodeConfig) error {
	log.Info("Fetching instance details..")
	instanceDetails, err := configprovider.FetchInstanceDetails()
	if err != nil {
		return err
	}
	cfg.Status.Instance = *instanceDetails
	log.Info("Instance details populated", zap.Reflect("details", instanceDetails))

	log.Info("Initializing empty configurations..")
	if cfg.Spec.Kubelet.AdditionalArguments == nil {
		cfg.Spec.Kubelet.AdditionalArguments = make(map[string]string)
	}

	if cfg.Spec.Cluster.Name == "" {
		return fmt.Errorf("Cluster name must be provided")
	}

	if featuregates.DefaultFalse(featuregates.DescribeClusterDetails, cfg.Spec.FeatureGates) {
		log.Info("Populating cluster details using a describe-cluster call..")
		if err := featuregates.PopulateClusterDetails(cfg); err != nil {
			return err
		}
	}

	// If the user doesn't specify a cluster dns address override then
	// it will be derived from the cluster CIDR ip range
	if cfg.Spec.Cluster.DNSAddress == "" {
		if cfg.Spec.Cluster.CIDR == "" {
			return fmt.Errorf("CIDR must be provided if DNSAddress is not")
		}
		log.Info("Constructing Cluster DNS..")
		clusterDns, err := util.AssembleClusterDns(cfg.Spec.Cluster.CIDR)
		if err != nil {
			return err
		}
		log.Info("Constructed Cluster DNS", zap.String("address", clusterDns))
		cfg.Spec.Cluster.DNSAddress = clusterDns
	}

	return nil
}
