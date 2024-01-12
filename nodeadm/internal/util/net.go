package util

import (
	"fmt"
	"net"
	"strings"
)

// Create a DNS Address based on a cluster CIDR ip range
func AssembleClusterDns(cidr string) (string, error) {
	ip, _, err := net.ParseCIDR(cidr)
	if err != nil {
		return "", fmt.Errorf("%s is not a valid CIDR address", cidr)
	}
	// if the IP parses, then it must be a valid format of either ipv4 or ipv6
	if ip.To4() != nil {
		cidrPrefix := cidr[:strings.LastIndex(cidr, ".")]
		return fmt.Sprintf("%s.10", cidrPrefix), nil
	} else {
		cidrPrefix := strings.Split(cidr, "/")[0]
		return fmt.Sprintf("%sa", cidrPrefix), nil
	}
}
