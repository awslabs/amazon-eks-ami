package config

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"go.uber.org/zap"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/kubelet"
)

// Various initializations and verifications of the NodeConfig and
// perform in-place updates when allowed by the user
func Enrich(log *zap.Logger, cfg *api.NodeConfig) error {
	log.Info("Fetching kubelet version..")
	kubeletVersion, err := kubelet.GetKubeletVersion()
	if err != nil {
		return err
	}
	cfg.Status.KubeletVersion = kubeletVersion
	log.Info("Fetched kubelet version", zap.String("version", kubeletVersion))
	log.Info("Fetching instance details..")
	awsConfig, err := config.LoadDefaultConfig(context.TODO(),
		config.WithClientLogMode(aws.LogRetries),
		config.WithEC2IMDSRegion(func(o *config.UseEC2IMDSRegion) {
			// Use our pre-configured IMDS client to avoid hitting common retry
			// issues with the default config.
			o.Client = imds.Client
		}),
	)
	if err != nil {
		return err
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
