#!/usr/bin/env bash

# This fixture also runs independently in a systemd >=258 container. It checks
# networkd's ownership semantics; the broker/EC2 decision is tested separately.
set -euo pipefail

deadline=$((SECONDS + 20))
until [ -S /run/systemd/private ]; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "systemd did not start" >&2
    exit 1
  fi
  sleep 0.2
done
systemctl start systemd-udevd systemd-networkd
version=$(systemctl --version | awk 'NR == 1 {print $2}')
echo "Checking networkd ownership on systemd $version"

mkdir -p /etc/udev/rules.d /run/systemd/network/80-ec2.network.d
cat > /etc/udev/rules.d/89-test-ownership.rules << 'EOF'
SUBSYSTEM=="net", KERNEL=="nm-systemd", ENV{ID_NET_MANAGED_BY}="io.systemd.Network"
SUBSYSTEM=="net", KERNEL=="nm-foreign", ENV{ID_NET_MANAGED_BY}="cni"
EOF
udevadm control --reload

# Reproduce the disabled EC2 fallback from disableDefaultEc2Networking.
cat > /run/systemd/network/80-ec2.network << 'EOF'
[Match]
Driver=dummy
[Network]
DHCP=yes
EOF
printf '[Match]\nName=none\n' > /run/systemd/network/80-ec2.network.d/10-eks-disable.conf

for interface in nm-default nm-systemd nm-foreign; do
  ip link add "$interface" type dummy
  udevadm trigger --action=add "/sys/class/net/$interface"
  udevadm settle
  if [ "$interface" != nm-default ]; then
    network=/run/systemd/network/70-eks-$interface.network
    cp 70-eks.network "$network"
    # Dummy links lack an ENA permanent MAC; select only the test device and
    # disable DHCP so this ownership test does not need a DHCP server.
    mkdir -p "$network.d"
    cat > "$network.d/10-test.conf" << EOF
[Match]
PermanentMACAddress=
Name=$interface
[Network]
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
ConfigureWithoutCarrier=yes
EOF
  fi
done
networkctl reload

function assert-selected() {
  local interface=$1 expected=$2 deadline=$((SECONDS + 20))
  local status
  while true; do
    status=$(networkctl status "$interface" --no-pager)
    if [ "$expected" = managed ]; then
      if [[ "$status" == *"/run/systemd/network/70-eks-$interface.network"* ]]; then
        return
      fi
    elif [[ "$status" == *"(unmanaged)"* ]]; then
      return
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "$status"
      journalctl -u systemd-networkd --no-pager -n 30
      return 1
    fi
    sleep 0.2
  done
}

assert-selected nm-default unmanaged
assert-selected nm-systemd managed
if [ "$version" -ge 258 ]; then
  assert-selected nm-foreign unmanaged
else
  # On v252 the property alone cannot exclude a matching .network. Nodeadm
  # instead avoids generating a file for CNI links and disables the fallback.
  assert-selected nm-foreign managed
fi
for interface in nm-default nm-systemd nm-foreign; do
  ip link delete "$interface"
done
echo "PASS networkd ownership on systemd $version"
