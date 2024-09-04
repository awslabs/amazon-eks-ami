#!/usr/bin/env bash

# EKS already forces amazon-ec2-net-utils to manage the primary ENI only (0/0):
# https://github.com/awslabs/amazon-eks-ami/pull/1738
#
# When VPC CNI is installed it creates another ENI from network card with index 0 (0/1).
# VPC CNI will continue adding additional ENIs until max number of interfaces for the intance
# is reached (0/2, 0/3, etc).
#
# This script configures IP and routing for Elastic Network Interfaces that are part of
# non-zero indexed EC2 network cards (1/0, 1/1, 2/1, 3/1, etc). The way we find out whether
# we need to configure the interface is by checking IMDS:
# /latest/meta-data/network/interfaces/macs/${mac_address}/network-card/
# This script will skip any interfaces that are part of the 0 indexed card.

cni_managed_card_index=0

instance_type=$(imds "/latest/meta-data/instance-type")
echo "instance type is $instance_type"

macs_array=($(imds '/latest/meta-data/network/interfaces/macs'))

if [[ "${#macs_array[@]}" -le 1 ]]; then
  echo "this instance does not have multiple network cards, skip configuration"
  exit 0
fi

table_id=1001
pref_id=32765

for mac in "${macs_array[@]}"; do
  trimmed_mac=$(echo $mac | sed 's:/*$::')
  if_name=$(ip -o link show | grep -F "link/ether $trimmed_mac" | awk -F'[ :]+' '{print $2}')
  ec2_card_index=$(imds "/latest/meta-data/network/interfaces/macs/${trimmed_mac}/network-card/")

  if [ "$ec2_card_index" -eq "$cni_managed_card_index" ]; then
    echo "skipping cni managed interface ${if_name} - ${trimmed_mac}"
  else
    echo "handling interface $if_name"

    if_ip_addr=$(imds "/latest/meta-data/network/interfaces/macs/$trimmed_mac/local-ipv4s" | head -1)
    vpc_subnet_cidr=$(imds "/latest/meta-data/network/interfaces/macs/$trimmed_mac/subnet-ipv4-cidr-block")

    network=$(echo ${vpc_subnet_cidr} | awk -F'/' '{print $1}')
    netmask=$(echo ${vpc_subnet_cidr} | awk -F'/' '{print $2}')
    router=$(($(echo ${network} | cut -d. -f4) + 1))
    default_gw_ip="$(echo ${network} | cut -d. -f1-3).${router}"

    echo "configuring IP addr: ${if_ip_addr}/${netmask} for ${if_name} ..."
    ip link set $if_name down
    ip addr add $if_ip_addr/$netmask metric 1024 dev $if_name
    ip link set dev $if_name mtu 9001

    echo "configuring routing for ${if_name} ..."
    ip link set $if_name up

    # add default gateway route
    ip route add default via $default_gw_ip dev $if_name table $table_id

    # add subnet route
    ip route add $vpc_subnet_cidr dev $if_name proto kernel scope link src $if_ip_addr table $table_id

    # add route rule
    ip rule add from $if_ip_addr lookup $table_id pref $pref_id

    ((table_id = table_id + 1))
    ((pref_id = pref_id - 1))
  fi
done
