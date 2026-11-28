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

func getInterfaceID(ctx context.Context, imdsClient imds.IMDSClient, mac string) (string, error) {
	return imdsClient.GetProperty(ctx, imds.InterfaceID(mac))
}

// getSubnetCIDRs returns the IPv4 and IPv6 CIDR blocks of the subnet that the
// interface with the given mac address belongs to. a subnet does not always
// have both address families, so a 404 for either property means that family
// is absent rather than an error.
func getSubnetCIDRs(ctx context.Context, imdsClient imds.IMDSClient, mac string) ([]string, error) {
	var cidrs []string
	for _, prop := range []imds.IMDSProperty{
		imds.SubnetIPv4CIDRBlock(mac),
		imds.SubnetIPv6CIDRBlocks(mac),
	} {
		value, err := imdsClient.GetProperty(ctx, prop)
		if err != nil {
			if isNotFoundErr(err) {
				continue
			}
			return nil, err
		}
		// subnet-ipv6-cidr-blocks can hold multiple newline-separated blocks.
		for _, cidr := range strings.Split(value, "\n") {
			if cidr = strings.TrimSpace(cidr); len(cidr) > 0 {
				cidrs = append(cidrs, cidr)
			}
		}
	}
	return cidrs, nil
}

func isNotFoundErr(err error) bool {
	// TODO: implement a more robust check. example data:
	// "operation error ec2imds: GetMetadata, http response error StatusCode: 404, request to EC2 IMDS failed"
	return strings.Contains(err.Error(), "StatusCode: 404")
}
