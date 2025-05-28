package ipamd

import (
	"context"
	"fmt"

	"github.com/aws/amazon-vpc-cni-k8s/pkg/grpcwrapper"
	"github.com/aws/amazon-vpc-cni-k8s/pkg/rpcwrapper"
	"google.golang.org/grpc"
	grpccodes "google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	grpcstatus "google.golang.org/grpc/status"

	"google.golang.org/protobuf/types/known/emptypb"
)

const cniBackendServerAddress = "127.0.0.1:50051"

func GetMaxAllocatableIPs() (int32, error) {
	grpcClient := grpcwrapper.New()
	conn, err := grpcClient.Dial(cniBackendServerAddress, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return 0, fmt.Errorf("failed to connect to ipamd server: %v", err)
	}
	defer conn.Close()

	cniBackendClient := rpcwrapper.New().NewCNIBackendClient(conn)
	resp, err := cniBackendClient.GetAllocatableValues(context.Background(), &emptypb.Empty{})
	if err != nil {
		return 0, err
	}
	if resp.MaxAllocatableIPs <= 0 {
		return 0, fmt.Errorf("received a non-positive value for max IPs: %d", resp.MaxAllocatableIPs)
	}
	return resp.MaxAllocatableIPs, nil
}

func IsErrIPAMDNotReady(err error) bool {
	return grpcstatus.Code(err) == grpccodes.Unavailable
}
