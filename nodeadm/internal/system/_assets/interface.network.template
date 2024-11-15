[Match]
PermanentMACAddress={{.PermanentMACAddress}}

[Link]
MTUBytes=9001

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
RouteMetric={{.RouteTableMetric}}
UseRoutes=true
UseGateway=true

[DHCPv6]
UseHostname=no
UseDNS=yes
UseNTP=yes
WithoutRA=solicit

[RoutingPolicyRule]
From={{.IpV4Address}}
Table={{.RouteTableId}}
Priority={{.RouteTableId}}

[RoutingPolicyRule]
From={{.IpV6Address}}
Table={{.RouteTableId}}
Priority={{.RouteTableId}}

[IPv6AcceptRA]
RouteMetric={{.RouteTableMetric}}
UseGateway=true

[Route]
Table={{.RouteTableId}}
Gateway=_ipv6ra

[Route]
Table={{.RouteTableId}}
Destination={{.IpV6Subnet}}

[Route]
Gateway=_dhcp4
Table={{.RouteTableId}}

[Route]
Table={{.RouteTableId}}
Destination={{.IpV4Subnet}}