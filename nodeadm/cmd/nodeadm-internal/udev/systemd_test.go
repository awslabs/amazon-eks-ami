package udev

import (
	_ "embed"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_renderNetworkTemplate(t *testing.T) {
	t.Run("Regular", func(t *testing.T) {
		networkConfig, err := renderNetworkTemplate(networkTemplateVars{
			MAC:         "foo",
			Metric:      42,
			TableID:     99,
			InterfaceIP: "127.0.0.1",
		})
		assert.NoError(t, err)
		assert.Equal(t, strings.TrimSpace(`
# this is derived from the ec2-net-util network config defaults.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network

[Match]
PermanentMACAddress=foo

[Link]
MTUBytes=9001

[Network]
DHCP=yes
IPv6DuplicateAddressDetection=0
LLMNR=no
DNSDefaultRoute=yes

[DHCPv4]
UseHostname=no
UseDNS=yes
UseNTP=yes
UseDomains=yes

[DHCPv6]
UseHostname=no
UseDNS=yes
UseNTP=yes
WithoutRA=solicit

# additional route optimization to promote the primary interface being more
# likely to carry traffic from the instance on boot.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L354-L366

[DHCPv4]
RouteMetric=42
UseRoutes=true
UseGateway=true

[IPv6AcceptRA]
RouteMetric=42
UseGateway=true

# additional routes/rules are only needed for interfaces besides the primary, so
# this block is optional depending on the route table id.

[Route]
Table=99
Gateway=_ipv6ra

[Route]
Table=99
Gateway=_dhcp4

[RoutingPolicyRule]
From=127.0.0.1
Table=99
# ref: https://github.com/aws/amazon-vpc-cni-k8s/blob/ee97808e926b2386846a0af772d468d99db5fc51/pkg/networkutils/network.go#L78
Priority=32765
	`), strings.TrimSpace(string(networkConfig)))
	})

	t.Run("NoInterfaceIP", func(t *testing.T) {
		networkConfig, err := renderNetworkTemplate(networkTemplateVars{
			MAC:     "foo",
			Metric:  42,
			TableID: 99,
		})
		assert.NoError(t, err)
		assert.Equal(t, strings.TrimSpace(`
# this is derived from the ec2-net-util network config defaults.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network

[Match]
PermanentMACAddress=foo

[Link]
MTUBytes=9001

[Network]
DHCP=yes
IPv6DuplicateAddressDetection=0
LLMNR=no
DNSDefaultRoute=yes

[DHCPv4]
UseHostname=no
UseDNS=yes
UseNTP=yes
UseDomains=yes

[DHCPv6]
UseHostname=no
UseDNS=yes
UseNTP=yes
WithoutRA=solicit

# additional route optimization to promote the primary interface being more
# likely to carry traffic from the instance on boot.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L354-L366

[DHCPv4]
RouteMetric=42
UseRoutes=true
UseGateway=true

[IPv6AcceptRA]
RouteMetric=42
UseGateway=true

# additional routes/rules are only needed for interfaces besides the primary, so
# this block is optional depending on the route table id.

[Route]
Table=99
Gateway=_ipv6ra

[Route]
Table=99
Gateway=_dhcp4
	`), strings.TrimSpace(string(networkConfig)))
	})

	t.Run("NoTableID", func(t *testing.T) {
		networkConfig, err := renderNetworkTemplate(networkTemplateVars{
			MAC:    "foo",
			Metric: 42,
		})
		assert.NoError(t, err)
		assert.Equal(t, strings.TrimSpace(`
# this is derived from the ec2-net-util network config defaults.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network

[Match]
PermanentMACAddress=foo

[Link]
MTUBytes=9001

[Network]
DHCP=yes
IPv6DuplicateAddressDetection=0
LLMNR=no
DNSDefaultRoute=yes

[DHCPv4]
UseHostname=no
UseDNS=yes
UseNTP=yes
UseDomains=yes

[DHCPv6]
UseHostname=no
UseDNS=yes
UseNTP=yes
WithoutRA=solicit

# additional route optimization to promote the primary interface being more
# likely to carry traffic from the instance on boot.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L354-L366

[DHCPv4]
RouteMetric=42
UseRoutes=true
UseGateway=true

[IPv6AcceptRA]
RouteMetric=42
UseGateway=true
	`), strings.TrimSpace(string(networkConfig)))
	})
}
