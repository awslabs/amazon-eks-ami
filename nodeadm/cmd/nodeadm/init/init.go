package init

import (
	"context"
	"slices"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
)

const (
	configPhase = "config"
	runPhase    = "run"
)

func NewInitCommand() cli.Command {
	c := initCmd{
		cmd: flaggy.NewSubcommand("init"),
	}
	c.cmd.Description = "Initialize this instance as a node in an EKS cluster"
	c.cmd.StringSlice(&c.daemons, "d", "daemon", "specify one or more of `containerd` and `kubelet`. This is intended for testing and should not be used in a production environment.")
	c.cmd.StringSlice(&c.skipPhases, "s", "skip", "phases of the bootstrap you want to skip")
	cli.RegisterFlagConfigCache(c.cmd, &c.configCache)
	cli.RegisterFlagConfigSources(c.cmd, &c.configSources)
	return &c
}

type initCmd struct {
	cmd           *flaggy.Subcommand
	configSources []string
	configCache   string
	skipPhases    []string
	daemons       []string
}

func (c *initCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *initCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	start := time.Now()

	log.Info("Checking user is root..")
	root, err := cli.IsRunningAsRoot()
	if err != nil {
		return err
	} else if !root {
		return cli.ErrMustRunAsRoot
	}

	c.configSources = cli.ResolveConfigSources(c.configSources)

	log.Info("Loading configuration..", zap.Strings("configSource", c.configSources), zap.String("configCache", c.configCache))

	nodeConfig, isChanged, shouldEnrichConfig, err := cli.ResolveConfig(log, c.configSources, c.configCache)
	if err != nil {
		return err
	}

	// nodeadmEnvAspect setups nodeadm envrionment that could be vital for bootstrapping.
	// For example, to enrich node config we might need to make EC2 API calls, which may
	// need to pass through an HTTP(s) proxy.
	log.Info("Setting up nodeadm environment aspect...")
	nodeadmEnvAspect := system.NewNodeadmEnvironmentAspect()
	if err := nodeadmEnvAspect.Setup(nodeConfig); err != nil {
		return err
	}

	if shouldEnrichConfig {
		// we don't need to enrich config when defaulting to a cache, since that is
		// the only time we already have the NodeConfig .status details populated.
		log.Info("Enriching configuration..")
		if err := c.enrichConfig(log, nodeConfig, opts); err != nil {
			return err
		}
	}
	log.Info("Loaded configuration", zap.Reflect("config", nodeConfig))

	log.Info("Validating configuration..")
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}

	log.Info("Creating daemon manager..")
	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()

	resources := system.NewResources(system.RealFileSystem{})
	daemons := []daemon.Daemon{
		containerd.NewContainerdDaemon(daemonManager, resources),
		kubelet.NewKubeletDaemon(daemonManager, resources),
	}

	// to handle edge cases where the cached config is stale (because the user
	// added configuration in between two invocations of nodeadm) we forcibly
	// re-run the the config phase to keep the system in sync.
	//
	// to make sure this is safe and mostly non-breaking, We ONLY enforce this
	// when we detect all the following:
	//  1. the caller is trying to use a cached config
	//  2. the specs between a cached config and regular config differ
	needsRecache := len(c.configCache) > 0 && isChanged

	if needsRecache || !slices.Contains(c.skipPhases, configPhase) {
		log.Info("Setting up system config aspects...")
		configAspects := []system.SystemAspect{
			system.NewInstanceEnvironmentAspect(),
			system.NewResolveAspect(),
		}
		if err := c.setupAspects(log, nodeConfig, configAspects); err != nil {
			return err
		}

		log.Info("Configuring daemons...")
		if err := c.configureDaemons(log, nodeConfig, daemons); err != nil {
			return err
		}

		// this is not fatal, so do not use a blocking error.
		if err := cli.SaveCachedConfig(nodeConfig, c.configCache); err != nil {
			log.Error("Failed to cache config", zap.String("configCache", c.configCache), zap.Error(err))
		}
	}

	if !slices.Contains(c.skipPhases, runPhase) {
		log.Info("Setting up system run aspects...")
		runAspects := []system.SystemAspect{
			system.NewMarkerAspect(),
			system.NewLocalDiskAspect(),
		}
		if err := c.setupAspects(log, nodeConfig, runAspects); err != nil {
			return err
		}

		log.Info("Running daemons...")
		if err := c.runDaemons(log, nodeConfig, daemons); err != nil {
			return err
		}
	}

	log.Info("done!", zap.Duration("duration", time.Since(start)))

	return nil
}

// enrichConfig populates the internal .status portion of the NodeConfig, used
// only for internal implementation details.
func (*initCmd) enrichConfig(log *zap.Logger, cfg *api.NodeConfig, opts *cli.GlobalOptions) error {
	log.Info("Fetching kubelet version..")
	kubeletVersion, err := kubelet.GetKubeletVersion()
	if err != nil {
		return err
	}
	cfg.Status.KubeletVersion = kubeletVersion
	log.Info("Fetched kubelet version", zap.String("version", kubeletVersion))
	log.Info("Fetching instance details..")
	awsClientLogMode := aws.LogRetries
	if opts.DevelopmentMode {
		// SDK v2 log modes are just bitwise operations, toggle all bits for maximum verbosity
		// https://github.com/aws/aws-sdk-go-v2/blob/838fb872e9701fc62b7b86164389791f5313bfcb/aws/logging.go#L18
		awsClientLogMode = aws.ClientLogMode((1 << 64) - 1)
	}
	awsConfig, err := config.LoadDefaultConfig(context.TODO(),
		config.WithClientLogMode(awsClientLogMode),
		config.WithEC2IMDSRegion(func(o *config.UseEC2IMDSRegion) {
			o.Client = imds.New(true /* treat 404's as retryable to make credential chain more resilient */)
		}),
	)
	if err != nil {
		return err
	}
	if awsConfig.RetryMaxAttempts == 0 {
		// use a very generous retry policy to accomodate delays in network readiness
		// we only specify the max attempts if it is unset by the user
		// so it's possible to override with the AWS_MAX_ATTEMPTS environment variable.
		// NOTE that this is the number of attempts that will be made in a blocking fashion
		// i.e. an SDK client.ExampleAPICall() will not return until these attempts are exhausted
		// we'll give up after approximately 10 minutes
		awsConfig.RetryMaxAttempts = 30
	}
	instanceDetails, err := api.GetInstanceDetails(context.TODO(), cfg.Spec.FeatureGates, ec2.NewFromConfig(awsConfig), imds.DefaultClient())
	if err != nil {
		return err
	}
	cfg.Status.Instance = *instanceDetails
	log.Info("Instance details populated", zap.Reflect("details", instanceDetails))
	log.Info("Fetching default options...")
	cfg.Status.Defaults = api.DefaultOptions{
		SandboxImage: "localhost/kubernetes/pause",
	}
	log.Info("Default options populated", zap.Reflect("defaults", cfg.Status.Defaults))
	return nil
}

func (c *initCmd) configureDaemons(log *zap.Logger, cfg *api.NodeConfig, daemons []daemon.Daemon) error {
	for _, daemon := range daemons {
		if len(c.daemons) > 0 && !slices.Contains(c.daemons, daemon.Name()) {
			continue
		}
		log := log.With(zap.String("name", daemon.Name()))

		log.Info("Configuring daemon...")
		if err := daemon.Configure(cfg); err != nil {
			return err
		}
		log.Info("Configured daemon")
	}
	return nil
}

func (c *initCmd) runDaemons(log *zap.Logger, cfg *api.NodeConfig, daemons []daemon.Daemon) error {
	for _, daemon := range daemons {
		if len(c.daemons) > 0 && !slices.Contains(c.daemons, daemon.Name()) {
			continue
		}
		log := log.With(zap.String("name", daemon.Name()))

		log.Info("Ensuring daemon is running..")
		if err := daemon.EnsureRunning(); err != nil {
			return err
		}
		log.Info("Daemon is running")

		log.Info("Running post-launch tasks..")
		if err := daemon.PostLaunch(cfg); err != nil {
			return err
		}
		log.Info("Finished post-launch tasks")
	}
	return nil
}

func (c *initCmd) setupAspects(log *zap.Logger, cfg *api.NodeConfig, aspects []system.SystemAspect) error {
	for _, aspect := range aspects {
		log := log.With(zap.String("name", aspect.Name()))

		log.Info("Setting up system aspect..")
		if err := aspect.Setup(cfg); err != nil {
			return err
		}
		log.Info("Set up system aspect")
	}
	return nil
}
