# this is a combination of the ec2-net-util network config defaults, and the
# interface config overrrides.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/lib/lib.sh#L354-L366

[Match]
Driver=ena ixgbevf vif
MACAddress={{.MAC}}

[Link]
MTUBytes=9001

[Network]
DHCP=yes
IPv6DuplicateAddressDetection=0
LLMNR=no
DNSDefaultRoute=yes

[DHCPv4]
RouteMetric={{.Metric}}
UseRoutes=true
UseGateway=true
UseHostname=no
UseDNS=yes
UseNTP=yes
UseDomains=yes

[DHCPv6]
UseHostname=no
UseDNS=yes
UseNTP=yes
WithoutRA=solicit

[IPv6AcceptRA]
RouteMetric={{.Metric}}
UseGateway=true
