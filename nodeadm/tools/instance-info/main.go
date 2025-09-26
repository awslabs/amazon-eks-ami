package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

func main() {
	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		panic(err)
	}
	instanceTypeInfos, err := util.GetGlobalSortedInstanceTypeInfo(ctx, cfg)
	if err != nil {
		panic(err)
	}
	for _, instanceTypeInfo := range instanceTypeInfos {
		infoBytes, err := json.Marshal(instanceTypeInfo)
		if err != nil {
			panic(err)
		}
		fmt.Println(string(infoBytes))
	}
}
