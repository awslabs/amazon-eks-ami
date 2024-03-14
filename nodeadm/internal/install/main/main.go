package main

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/install"
)

func main() {
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion("us-west-2"), config.WithSharedConfigFiles([]string{}))
	if err != nil {
		panic(err)
	}
	err = install.Install(context.Background(), "1.27", api.NodeConfig{}, cfg)
	if err != nil {
		panic(err)
	}
}
