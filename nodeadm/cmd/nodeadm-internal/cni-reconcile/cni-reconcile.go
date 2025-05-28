package cnireconcile

import (
	"context"
	"fmt"
	"time"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/config"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
)

func NewCNIReconcileCommand() cli.Command {
	cniReconcile := cniReconcileCommand{}
	cniReconcile.cmd = flaggy.NewSubcommand("cni-reconcile")
	return &cniReconcile
}

type cniReconcileCommand struct {
	cmd *flaggy.Subcommand
}

func (c *cniReconcileCommand) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *cniReconcileCommand) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	start := time.Now()

	log.Info("Checking user is root..")
	root, err := cli.IsRunningAsRoot()
	if err != nil {
		return err
	} else if !root {
		return cli.ErrMustRunAsRoot
	}

	ctx := context.Background()
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

	zap.L().Info("Validating configuration..")
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}

	if !api.IsFeatureEnabled(api.CNIReconcile, nodeConfig.Spec.FeatureGates) {
		log.Info("Fast exiting, feature was not enabled", zap.String("featureGate", string(api.CNIReconcile)))
		return nil
	}

	log.Info("Enriching configuration..")
	if err := config.Enrich(log, nodeConfig); err != nil {
		return err
	}

	if !kubelet.SupportsDropinConfigs(nodeConfig.Status.KubeletVersion) {
		return fmt.Errorf("kubelet must support config directories, but the running version (%s) does not", nodeConfig.Status.KubeletVersion)
	}

	log.Info("Creating daemon manager..")
	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()
	kubeletDaemon := kubelet.NewKubeletDaemon(daemonManager)

	// This should only write if the file does not already exist, assumes that if it does exist
	// then kubelet already loaded it. CNI features should only be considered in the initial run,
	// changing some features on a running node can lead to unpredictable behavior
	if exists, err := kubelet.CNIConfigExists(); err != nil {
		return err
	} else if exists {
		log.Info("Fast exiting, reconciliation was previously completed.")
		return nil
	}

	log.Info("Generating kubelet configuration for CNI..")
	if err := kubelet.ConfigureCNIBasedConfig(ctx, nodeConfig); err != nil {
		return err
	}

	log.Info("Restarting kubelet with new config..")
	if err := kubeletDaemon.Restart(); err != nil {
		return err
	}

	log.Info("done!", zap.Duration("duration", time.Since(start)))
	return nil
}
