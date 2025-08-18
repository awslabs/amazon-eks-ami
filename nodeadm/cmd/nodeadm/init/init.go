package init

import (
	"context"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/integrii/flaggy"
	"go.uber.org/zap"
	"k8s.io/utils/strings/slices"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
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
	init := initCmd{}
	init.cmd = flaggy.NewSubcommand("init")
	init.cmd.StringSlice(&init.daemons, "d", "daemon", "specify one or more of `containerd` and `kubelet`. This is intended for testing and should not be used in a production environment.")
	init.cmd.StringSlice(&init.skipPhases, "s", "skip", "phases of the bootstrap you want to skip")
	init.cmd.Description = "Initialize this instance as a node in an EKS cluster"
	return &init
}

type initCmd struct {
	cmd        *flaggy.Subcommand
	skipPhases []string
	daemons    []string
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
	if err := enrichConfig(log, nodeConfig, opts); err != nil {
		return err
	}

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

	aspects := []system.SystemAspect{
		system.NewLocalDiskAspect(),
	}

	daemons := []daemon.Daemon{
		containerd.NewContainerdDaemon(daemonManager, system.SysfsResources{}),
		kubelet.NewKubeletDaemon(daemonManager, system.SysfsResources{}),
	}

	if !slices.Contains(c.skipPhases, configPhase) {
		log.Info("Configuring daemons...")
		for _, daemon := range daemons {
			if len(c.daemons) > 0 && !slices.Contains(c.daemons, daemon.Name()) {
				continue
			}
			nameField := zap.String("name", daemon.Name())

			log.Info("Configuring daemon...", nameField)
			if err := daemon.Configure(nodeConfig); err != nil {
				return err
			}
			log.Info("Configured daemon", nameField)
		}
	}

	if !slices.Contains(c.skipPhases, runPhase) {
		log.Info("Setting up system aspects...")
		for _, aspect := range aspects {
			nameField := zap.String("name", aspect.Name())
			log.Info("Setting up system aspect..", nameField)
			if err := aspect.Setup(nodeConfig); err != nil {
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
			if err := daemon.PostLaunch(nodeConfig); err != nil {
				return err
			}
			log.Info("Finished post-launch tasks", nameField)
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
			// Use our pre-configured IMDS client to avoid hitting common retry
			// issues with the default config.
			o.Client = imds.Client
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
	instanceDetails, err := api.GetInstanceDetails(context.TODO(), cfg.Spec.FeatureGates, ec2.NewFromConfig(awsConfig))
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
