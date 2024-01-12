package util

import (
	"fmt"
	"net"
	"strings"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

func GetClusterDns(details *api.ClusterDetails) (string, error) {
	ipFamily, err := GetIpFamily(details.CIDR)
	if err != nil {
		return "", err
	}

	switch ipFamily {
	case api.IPFamilyIPv4:
		dnsAddress := fmt.Sprintf("%s.10", details.CIDR[:strings.LastIndex(details.CIDR, ".")])
		return dnsAddress, nil
	case api.IPFamilyIPv6:
		dnsAddress := fmt.Sprintf("%sa", details.CIDR[:strings.LastIndex(details.CIDR, "/")])
		return dnsAddress, nil
	default:
		return "", fmt.Errorf("%s was not a valid IP family", ipFamily)
	}
}

func GetIpFamily(cidr string) (api.IPFamily, error) {
	ip, _, err := net.ParseCIDR(cidr)
	if err != nil {
		return "", fmt.Errorf("%s is not a valid IP Address. error: %v", cidr, err)
	}
	if ip.To4() != nil {
		return api.IPFamilyIPv4, nil
	} else {
		return api.IPFamilyIPv6, nil
	}
}
