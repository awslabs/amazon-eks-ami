package ipamd

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/amazon-vpc-cni-k8s/pkg/grpcwrapper"
	"github.com/aws/amazon-vpc-cni-k8s/pkg/rpcwrapper"
	smithytime "github.com/aws/smithy-go/time"
	"google.golang.org/grpc"
	grpccodes "google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	grpcstatus "google.golang.org/grpc/status"

	"google.golang.org/protobuf/types/known/emptypb"
)

const (
	// This should be long enough to ensure that kubelet has sufficient time to register
	// with the cluster and then eventaully run the VPC CNI
	interrogationDeadline = 1 * time.Hour

	// This should be short enough to ensure that the first running instance of the VPC CNI
	// is caught, or specifically, that no two different configurations of ipamd manage running
	// pods before this returns.
	interrogationBackOff = 5 * time.Second
)

const cniBackendServerAddress = "127.0.0.1:50051"

func PollMaxAllocatableIPs(ctx context.Context) (int32, error) {
	timedCtx, cancelTimedCtx := context.WithTimeout(ctx, interrogationDeadline)
	defer cancelTimedCtx()
	for {
		maxPods, err := GetMaxAllocatableIPs(timedCtx)
		if err != nil {
			return maxPods, err
		} else if !IsErrIPAMDNotReady(err) {
			return -1, fmt.Errorf("got error while interrogating max pods from the CNI: %v", err)
		}

		if sleepErr := smithytime.SleepWithContext(timedCtx, interrogationBackOff); sleepErr != nil {
			// bubble up the original error, not the context cancel
			return -1, err
		}
	}

}

func GetMaxAllocatableIPs(ctx context.Context) (int32, error) {
	grpcClient := grpcwrapper.New()
	conn, err := grpcClient.Dial(cniBackendServerAddress, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return -1, fmt.Errorf("failed to connect to ipamd server: %v", err)
	}
	defer conn.Close()

	cniBackendClient := rpcwrapper.New().NewCNIBackendClient(conn)
	resp, err := cniBackendClient.GetAllocatableValues(ctx, &emptypb.Empty{})
	if err != nil {
		return -1, err
	}
	if resp.MaxAllocatableIPs <= 0 {
		return -1, fmt.Errorf("received a non-positive value for max IPs: %d", resp.MaxAllocatableIPs)
	}
	return resp.MaxAllocatableIPs, nil
}

func IsErrIPAMDNotReady(err error) bool {
	return grpcstatus.Code(err) == grpccodes.Unavailable
}
