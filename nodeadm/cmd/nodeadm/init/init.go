package init

import (
	"context"
	"errors"
	"fmt"
	"reflect"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
	"k8s.io/utils/strings/slices"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	apibridge "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api/bridge"
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
		configCache: "/run/eks/nodeadm/config.json",
	}
	c.cmd = flaggy.NewSubcommand("init")
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

	log.Info("Loading configuration..", zap.Strings("configSource", c.configSources))
	var cachedConfig *api.NodeConfig
	if len(c.configCache) > 0 {
		c, err := loadCachedConfig(c.configCache)
		if err != nil {
			log.Warn("did not load cached config", zap.Error(err))
		}
		cachedConfig = c
	}
	provider, err := configprovider.BuildConfigProviderChain(c.configSources)
	if err != nil {
		return err
	}
	nodeConfig, err := provider.Provide()
	// if we have a cached config, tolerate an empty result from the chain
	if cachedConfig != nil && errors.Is(err, configprovider.ErrNoConfigInChain) {
		log.Info("Using cached config...")
	} else if err != nil {
		return err
	}
	log.Info("Loaded configuration", zap.Reflect("config", nodeConfig))

	// if perf of reflect.DeepEqual becomes an issue, look into something like: https://github.com/Wind-River/deepequal-gen
	configHasChanged := cachedConfig == nil || reflect.DeepEqual(nodeConfig.Spec, cachedConfig.Spec)

	if configHasChanged {
		log.Info("Enriching configuration..")
		if err := enrichConfig(log, nodeConfig, opts); err != nil {
			return err
		}
	}

	// This let's nodeadm respect any environment variables that may be critical for
	// the node's initialization. For example, prior to config phase, we make calls to EC2's API to
	// get instance details which could pass through an HTTP(s) proxy.
	initAspects := []system.SystemAspect{
		system.NewNodeadmEnvironmentAspect(),
	}
	log.Info("Setting up system init aspects...")
	for _, aspect := range initAspects {
		nameField := zap.String("name", aspect.Name())
		log.Info("Setting up system init aspect..", nameField)
		if err := aspect.Setup(nodeConfig); err != nil {
			return err
		}
		log.Info("Set up system init aspect", nameField)
	}

	// validate unconditionally, a cached config may no longer be valid
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

	configAspects := []system.SystemAspect{
		system.NewInstanceEnvironmentAspect(),
	}

	daemons := []daemon.Daemon{
		containerd.NewContainerdDaemon(daemonManager, system.SysfsResources{}),
		kubelet.NewKubeletDaemon(daemonManager, system.SysfsResources{}),
	}

	if configHasChanged || !slices.Contains(c.skipPhases, configPhase) {
		if err := c.configPhase(log, nodeConfig, daemons); err != nil {
			return err
		}
		if err := writeCachedConfig(nodeConfig, c.configCache); err != nil {
			return fmt.Errorf("failed to cache config at path %q: %v", c.configCache, err)
		}
	}

	runAspects := []system.SystemAspect{
		system.NewLocalDiskAspect(),
	}

	if !slices.Contains(c.skipPhases, runPhase) {
		if err := c.runPhase(log, nodeConfig, daemons, runAspects); err != nil {
			return err
		}
	}

	log.Info("done!", zap.Duration("duration", time.Since(start)))

	return nil
}

// Various initializations and verifications of the NodeConfig and
// perform in-place updates when allowed by the user
func enrichConfig(log *zap.Logger, cfg *api.NodeConfig, opts *cli.GlobalOptions) error {
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
	provider, err := configprovider.BuildConfigProvider("file://" + path)
	if err != nil {
		return nil, fmt.Errorf("failed to build provider for cached config path %q: %v", path, err)
	}
	return provider.Provide()
}

func writeCachedConfig(cfg *api.NodeConfig, path string) error {
	data, err := apibridge.EncodeNodeConfig(cfg)
	if err != nil {
		return err
	}
	return util.WriteFileWithDir(path, data, 0644)
}

func (c *initCmd) configPhase(log *zap.Logger, cfg *api.NodeConfig, daemons []daemon.Daemon) error {
	log.Info("Configuring daemons...")
	for _, daemon := range daemons {
		if len(c.daemons) > 0 && !slices.Contains(c.daemons, daemon.Name()) {
			continue
		}
		nameField := zap.String("name", daemon.Name())

		log.Info("Configuring daemon...", nameField)
		if err := daemon.Configure(cfg); err != nil {
			return err
		}
		log.Info("Configured daemon", nameField)
	}
	return nil
}

func (c *initCmd) runPhase(log *zap.Logger, cfg *api.NodeConfig, daemons []daemon.Daemon, aspects []system.SystemAspect) error {
	log.Info("Setting up system aspects...")
	for _, aspect := range aspects {
		nameField := zap.String("name", aspect.Name())
		log.Info("Setting up system aspect..", nameField)
		if err := aspect.Setup(cfg); err != nil {
			return err
		}
		log.Info("Set up system aspect", nameField)
	}
	for _, daemon := range daemons {
		if len(c.daemons) > 0 && !slices.Contains(c.daemons, daemon.Name()) {
			continue
		}
		nameField := zap.String("name", daemon.Name())

		log.Info("Ensuring daemon is running..", nameField)
		if err := daemon.EnsureRunning(); err != nil {
			return err
		}
		log.Info("Daemon is running", nameField)

		log.Info("Running post-launch tasks..", nameField)
		if err := daemon.PostLaunch(cfg); err != nil {
			return err
		}
		log.Info("Finished post-launch tasks", nameField)
	}
	return nil
}
