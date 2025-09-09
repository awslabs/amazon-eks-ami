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
