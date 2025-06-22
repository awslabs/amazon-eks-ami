package main

import (
	"context"
	"fmt"
	"time"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/configprovider"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
)

const (
	// reconcileConfigFileName is the name of a drop-in config file for kubelet configs made after initial kubelet
	// start.
	reconcileConfigFileName = "20-nodeadm.conf"
)

var (
	interrogationDeadline = 5 * time.Minute
	interrogationBackoff  = 1 * time.Second
)

func newCNIReconcileCommand() cli.Command {
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

	mainCtx := context.Background()
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
	if err := cli.EnrichConfig(log, nodeConfig); err != nil {
		return err
	}

	zap.L().Info("Validating configuration..")
	if err := api.ValidateNodeConfig(nodeConfig); err != nil {
		return err
	}

	if !api.IsFeatureEnabled(api.CNIReconcile, nodeConfig.Spec.FeatureGates) {
		log.Info("Fast exiting, feature was not enabled", zap.String("featureGate", string(api.CNIReconcile)))
		return nil
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
	if exists, err := kubelet.DropinConfigExists(reconcileConfigFileName); err != nil {
		return err
	} else if exists {
		log.Info("Fast exiting, reconciliation was previously completed.")
		return nil
	}

	log.Info("Reconciling config with running CNI...")
	maxPods, err := kubelet.PollInterrogateMaxPods(mainCtx, interrogationDeadline, interrogationBackoff)
	if err != nil {
		return err
	}

	log.Info("Received response from CNI, generating new config...", zap.Int32("maxPods", maxPods))
	kubeletCfg := kubelet.NewKubeletConfig()
	kubeletCfg.WithReservedResources(maxPods)

	if err := kubelet.WriteDropinConfigFile(kubeletCfg, reconcileConfigFileName); err != nil {
		return err
	}

	log.Info("Restarting kubelet with new config..")
	if err := kubeletDaemon.Restart(); err != nil {
		return err
	}

	log.Info("done!", zap.Duration("duration", time.Since(start)))
	return nil
}
