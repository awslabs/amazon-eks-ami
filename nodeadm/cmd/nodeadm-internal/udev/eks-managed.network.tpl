# this is derived from the ec2-net-util network config defaults.
#
# see: https://github.com/amazonlinux/amazon-ec2-net-utils/blob/3261b3b4c8824343706ee54d4a6f5d05cd8a5979/systemd/network/80-ec2.network

[Match]
PermanentMACAddress={{.MAC}}

[Link]
MTUBytes=9001

[Network]
DHCP=yes
IPv6DuplicateAddressDetection=0
LLMNR=no
DNSDefaultRoute=yes

[DHCPv4]
UseHostname=no
UseDNS={{.UseDNS}}
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
RouteMetric={{.Metric}}
UseRoutes=true
UseGateway=true

[IPv6AcceptRA]
RouteMetric={{.Metric}}
UseGateway=true

{{ if .TableID -}}
# additional routes/rules are only needed for interfaces besides the primary, so
# this block is optional depending on the route table id.

[Route]
Table={{.TableID}}
Gateway=_ipv6ra

[Route]
Table={{.TableID}}
Gateway=_dhcp4

{{ if .InterfaceIP -}}
[RoutingPolicyRule]
From={{.InterfaceIP}}
Table={{.TableID}}
# ref: https://github.com/aws/amazon-vpc-cni-k8s/blob/ee97808e926b2386846a0af772d468d99db5fc51/pkg/networkutils/network.go#L78
Priority=32765
{{ end -}}
{{ end -}}
