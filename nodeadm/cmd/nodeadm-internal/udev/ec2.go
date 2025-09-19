package udev

import (
	"context"
	"strconv"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
)

func getDeviceIndex(ctx context.Context, imdsClient imds.IMDSClient, mac string) (int, error) {
	deviceIndex, err := imdsClient.GetProperty(ctx, imds.DeviceIndex(mac))
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(deviceIndex)
}

func getNetworkCard(ctx context.Context, imdsClient imds.IMDSClient, mac string) (int, error) {
	networkCard, err := imdsClient.GetProperty(ctx, imds.NetworkCard(mac))
	if err != nil {
		// the 'network-card' property in IMDS may or may not exist depending on
		// the whether the instance type is multi-nic enabled, and in cases
		// where it is not the 404 should be translated to the 0'th index.
		if isNotFoundErr(err) {
			return 0, nil
		}
		return 0, err
	}
	return strconv.Atoi(networkCard)
}

func isNotFoundErr(err error) bool {
	// TODO: implement a more robust check. example data:
	// "operation error ec2imds: GetMetadata, http response error StatusCode: 404, request to EC2 IMDS failed"
	return strings.Contains(err.Error(), "StatusCode: 404")
}
