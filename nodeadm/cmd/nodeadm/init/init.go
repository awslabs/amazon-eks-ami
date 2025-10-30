package init

import (
	"context"
	"errors"
	"os"
	"reflect"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
	"k8s.io/utils/strings/slices"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/containerd"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
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
	c.cmd.String(&c.configCache, "", "config-cache", "File path at which to cache the resolved/enriched config. This can make repeated init calls more efficient. JSON encoding will be used.")
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

	initAspects := []system.SystemAspect{
		// This aspect enables nodeadm to respect environment variables that
		// could be vital for bootstrapping. For example, to enrich node config
		// we might need to make EC2 API calls, which may need to pass through
		// an HTTP(s) proxy.
		system.NewNodeadmEnvironmentAspect(),
	}

	nodeConfig, isChanged, err := c.resolveConfig(log, opts, initAspects)
	if err != nil {
		return err
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

	daemons := []daemon.Daemon{
		containerd.NewContainerdDaemon(daemonManager, system.SysfsResources{}),
		kubelet.NewKubeletDaemon(daemonManager, system.SysfsResources{}),
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
		}
		if err := c.setupAspects(log, nodeConfig, configAspects); err != nil {
			return err
		}

		log.Info("Configuring daemons...")
		if err := c.configureDaemons(log, nodeConfig, daemons); err != nil {
			return err
		}

		// this is not fatal, so do not use a blocking error.
		if err := saveCachedConfig(nodeConfig, c.configCache); err != nil {
			log.Error("Failed to cache config", zap.String("configCache", c.configCache), zap.Error(err))
		}
	}

	if !slices.Contains(c.skipPhases, runPhase) {
		log.Info("Setting up system run aspects...")
		runAspects := []system.SystemAspect{
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

// resolveConfig returns either the cached config or the provided config chain.
func (c *initCmd) resolveConfig(log *zap.Logger, opts *cli.GlobalOptions, initAspects []system.SystemAspect) (cfg *api.NodeConfig, isChanged bool, err error) {
	var cachedConfig *api.NodeConfig
	if len(c.configCache) > 0 {
		config, err := loadCachedConfig(c.configCache)
		if err != nil {
			log.Warn("failed to load cached config", zap.Error(err))
		} else {
			cachedConfig = config
		}
	}

	provider, err := configprovider.BuildConfigProviderChain(c.configSources)
	if err != nil {
		return nil, false, err
	}
	nodeConfig, err := provider.Provide()
	// if the error is just that no config is provided, then attempt to use the
	// cached config as a fallback. otherwise, treat this as a fatal error.
	if errors.Is(err, configprovider.ErrNoConfigInChain) && cachedConfig != nil {
		log.Warn("Falling back to cached config...")
		return cachedConfig, false, nil
	} else if err != nil {
		return nil, false, err
	}

	log.Info("Setting up system init aspects...")
	if err := c.setupAspects(log, nodeConfig, initAspects); err != nil {
		return nil, false, err
	}

	// if the cached and the provider config specs are the same, we'll just
	// use the cached spec because it also has the internal NodeConfig
	// .status information cached.
	//
	// if perf of reflect.DeepEqual becomes an issue, look into something like: https://github.com/Wind-River/deepequal-gen
	if cachedConfig != nil && reflect.DeepEqual(nodeConfig.Spec, cachedConfig.Spec) {
		return cachedConfig, false, nil
	}

	// we don't need to enrich config when defaulting to a cache, since that is
	// the only time we already have the NodeConfig .status details populated.
	log.Info("Enriching configuration..")
	if err := c.enrichConfig(log, nodeConfig, opts); err != nil {
		return nil, false, err
	}
	// we return the presence of a cache as the `isChanged` value, because if we
	// had a cache hit and didnt use it, it's because we have a modified config.
	return nodeConfig, cachedConfig != nil, nil
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

func loadCachedConfig(path string) (*api.NodeConfig, error) {
	// #nosec G304 // intended mechanism to read user-provided config file
	nodeConfigData, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	gvk := bridge.InternalGroupVersion.WithKind(api.KindNodeConfig)
	return bridge.DecodeNodeConfig(nodeConfigData, &gvk)
}

func saveCachedConfig(cfg *api.NodeConfig, path string) error {
	data, err := bridge.EncodeNodeConfig(cfg)
	if err != nil {
		return err
	}
	return util.WriteFileWithDir(path, data, 0644)
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
