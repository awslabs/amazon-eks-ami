#!/usr/bin/env bash

INSTANCE_TYPE=$(imds "/latest/meta-data/instance-type")
echo "instance type is $INSTANCE_TYPE"

ALL_MACS=$(imds '/latest/meta-data/network/interfaces/macs')
MAC_ARRAY=("$ALL_MACS")

if [[ "${#MAC_ARRAY[@]}" -le 1 ]]; then
  echo "this instance does not have multiple network card, skip configuration"
  exit 0
fi

PRIMARY_MAC=$(imds '/latest/meta-data/mac')
PRIMARY_IF=$(ip -o link show | grep -F "link/ether $PRIMARY_MAC" | awk -F'[ :]+' '{print $2}')

TABLE_ID=1001
PREF_ID=32765
for MAC in "${MAC_ARRAY[@]}"; do
  TRIMMED_MAC=$(echo $MAC | sed 's:/*$::')
  echo "Processing MAC $TRIMMED_MAC"
  ALL_INTERFACE_FIELDS=$(imds "/latest/meta-data/network/interfaces/macs/$TRIMMED_MAC/")
  FIELDS_ARRAY=("$ALL_INTERFACE_FIELDS")
  EFA_ONLY_INTERFACE=true
  for field in "${FIELDS_ARRAY[@]}"; do
    if [[ "$field" == "local-ipv4s" ]]; then
      IPV4s=$(imds "/latest/meta-data/network/interfaces/macs/$TRIMMED_MAC/local-ipv4s/")
      if [ -n "$IPV4s" ]; then
        EFA_ONLY_INTERFACE=false
        break
      fi
    fi
    if [ "$field" == "local-ipv6s" ]; then
      IPV6s=$(imds "/latest/meta-data/network/interfaces/macs/$TRIMMED_MAC/local-ipv6s/")
      if [ -n "$IPV6s" ]; then
        EFA_ONLY_INTERFACE=false
        break
      fi
    fi
  done

  if [ "$EFA_ONLY_INTERFACE" = true ]; then
    echo "$TRIMMED_MAC is EFA-only interface. Skipping configuring the interface"
    continue
  fi

  IF_NAME=$(ip -o link show | grep -F "link/ether $TRIMMED_MAC" | awk -F'[ :]+' '{print $2}')

  echo "handling interface $IF_NAME"

  config_file="/etc/sysconfig/network-scripts/ifcfg-${IF_NAME}"
  route_file="/etc/sysconfig/network-scripts/route-${IF_NAME}"
  if [ "$IF_NAME" = "$PRIMARY_IF" ]; then
    echo "skipping primary interface"
  else
    ifdown $IF_NAME
    rm -f ${config_file}
    rm -f ${route_file}
    IF_IP=$(imds "/latest/meta-data/network/interfaces/macs/$TRIMMED_MAC/local-ipv4s" | head -1)
    echo "got interface ip $IF_IP"
    CIDR=$(imds "/latest/meta-data/network/interfaces/macs/$TRIMMED_MAC/subnet-ipv4-cidr-block")

    echo "got cidr $CIDR"
    echo "using table $TABLE_ID"
    echo "using rule preference $PREF_ID"

    network=$(echo ${CIDR} | cut -d/ -f1)
    router=$(($(echo ${network} | cut -d. -f4) + 1))
    GATEWAY_IP="$(echo ${network} | cut -d. -f1-3).${router}"
    echo $GATEWAY_IP
    cat <<- EOF > ${config_file}
			DEVICE=${IF_NAME}
			BOOTPROTO=dhcp
			ONBOOT=yes
			TYPE=Ethernet
			USERCTL=yes
			PEERDNS=no
			IPV6INIT=yes
			DHCPV6C=yes
			DHCPV6C_OPTIONS=-nw
			PERSISTENT_DHCLIENT=yes
			HWADDR=${TRIMMED_MAC}
			DEFROUTE=no
			EC2SYNC=yes
			MAINROUTETABLE=no
		EOF

    ip link set dev $IF_NAME mtu 9001
    ifup $IF_NAME

    ip route add default via $GATEWAY_IP dev $IF_NAME table $TABLE_ID
    ip route add $CIDR dev $IF_NAME proto kernel scope link src $IF_IP table $TABLE_ID
    ip rule add from $IF_IP lookup $TABLE_ID pref $PREF_ID

    ((TABLE_ID = TABLE_ID + 1))
    ((PREF_ID = PREF_ID - 1))
  fi
done
