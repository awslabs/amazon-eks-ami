package daemon

import (
	"context"
	"fmt"
	"reflect"
	"time"

	"github.com/integrii/flaggy"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/cli"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/daemon"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
)

var (
	instanceType string
	region       string

	previousConfig *kubelet.KubeletConfig
)

const configFileName = "99-nodeadm-dynamic.conf"

// TODO: bump up to n hour(s) before finalizing
var delayTime = 5 * time.Second

func NewConfigCheckCommand() cli.Command {
	configSync := configSyncCmd{}
	configSync.cmd = flaggy.NewSubcommand("config-sync")
	return &configSync
}

type configSyncCmd struct {
	cmd *flaggy.Subcommand
}

func (c *configSyncCmd) Flaggy() *flaggy.Subcommand {
	return c.cmd
}

func (c *configSyncCmd) runLoop(log *zap.Logger, kubeletDaemon daemon.Daemon) error {
	kubeletCfg := kubelet.NewKubeletConfig()
	kubeletCfg.WithDefaultReservedResources(instanceType, region)

	if previousConfig != nil && reflect.DeepEqual(*previousConfig, kubeletCfg) {
		return nil
	}

	log.Info("Discovered change in dynamic kubelet config")
	previousConfig = &kubeletCfg

	if err := kubelet.WriteDropinConfigFile(kubeletCfg, configFileName); err != nil {
		return err
	}

	log.Info("Restarting kubelet..")
	return kubeletDaemon.Restart()
}

func (c *configSyncCmd) Run(log *zap.Logger, opts *cli.GlobalOptions) error {
	log.Info("Verifying running as root..")
	root, err := cli.IsRunningAsRoot()
	if err != nil {
		return err
	} else if !root {
		return cli.ErrMustRunAsRoot
	}

	log.Info("Creating daemon manager..")
	daemonManager, err := daemon.NewDaemonManager()
	if err != nil {
		return err
	}
	defer daemonManager.Close()

	kubeletDaemon := kubelet.NewKubeletDaemon(daemonManager)

	for {
		err := c.runLoop(log, kubeletDaemon)
		log.Info("Finished sync", zap.Error(err))
		log.Info("Sleeping..", zap.String("sleepInterval", delayTime.String()))
		time.Sleep(delayTime)
	}

}

func init() {
	instanceIdenitityDocument, err := imds.GetInstanceIdentityDocument(context.TODO())
	if err != nil {
		panic(fmt.Errorf("failed to load instance details: %v", instanceIdenitityDocument))
	}

	instanceType = instanceIdenitityDocument.InstanceType
	region = instanceIdenitityDocument.Region
}
