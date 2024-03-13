package api

import (
	"fmt"
	"net"
	"strings"
)

// Derive the default ClusterIP of the kube-dns service from EKS built-in CoreDNS addon
func (details *ClusterDetails) GetClusterDns() (string, error) {
	ipFamily, err := GetCIDRIpFamily(details.CIDR)
	if err != nil {
		return "", err
	}
	switch ipFamily {
	case IPFamilyIPv4:
		dnsAddress := fmt.Sprintf("%s.10", details.CIDR[:strings.LastIndex(details.CIDR, ".")])
		return dnsAddress, nil
	case IPFamilyIPv6:
		dnsAddress := fmt.Sprintf("%sa", strings.Split(details.CIDR, "/")[0])
		return dnsAddress, nil
	default:
		return "", fmt.Errorf("%s was not a valid IP family", ipFamily)
	}
}

func GetCIDRIpFamily(cidr string) (IPFamily, error) {
	ip, _, err := net.ParseCIDR(cidr)
	if err != nil {
		return "", fmt.Errorf("%s is not a valid IP Address. error: %v", cidr, err)
	}
	if ip.To4() != nil {
		return IPFamilyIPv4, nil
	} else {
		return IPFamilyIPv6, nil
	}
}
