#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh
mock::aws
mock::kubelet 1.34.0
wait::dbus-ready

# a dummy link carrying the mocked primary MAC stands in for the ENI, since
# moto and the metadata mock only know that one address.
interface=nm-test
ip link add "$interface" address 0e:49:61:0f:c3:11 type dummy
instance_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)
eni_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId' --output text)
cache=/etc/eks/nodeadm/udev-net-manager/$instance_id/$interface
network=/run/systemd/network/70-eks-$interface.network
unit=udev-net-manager@$interface.service
no_manage_tag="Key=node.k8s.amazonaws.com/no_manage,Value=true"

nodeadm init --daemon="" --config-source file://config.yaml
test -f /run/nodeadm/init
test -f /run/nodeadm/os-managed-no-manage-enis

# run the production unit, only the executable path and AWS endpoints differ.
ln -s /usr/local/bin/nodeadm-internal /usr/bin/nodeadm-internal
cp /udev-net-manager@.service /etc/systemd/system/
mkdir -p /etc/systemd/system/udev-net-manager@.service.d
env | grep '^AWS_' > /run/net-manager-test.env
cat << 'EOF' > /etc/systemd/system/udev-net-manager@.service.d/test.conf
[Service]
EnvironmentFile=/run/net-manager-test.env
EOF
systemctl daemon-reload
systemctl start systemd-udevd
udevadm trigger --action=add "/sys/class/net/$interface"
udevadm settle
# dummy links have no permanent MAC, so match the generated network by name.
mkdir -p "$network.d"
cat << EOF > "$network.d/10-test-match.conf"
[Match]
PermanentMACAddress=
Name=$interface
EOF
systemctl start systemd-networkd

function wait::until() {
  local deadline=$((SECONDS + 60))
  until "$@"; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      journalctl -u "$unit" --no-pager
      return 1
    fi
    sleep 0.2
  done
}

function ownership-pending() {
  journalctl -u "$unit" --no-pager | grep -q "tags not yet visible"
}

function networkd-selected-config() {
  networkctl status "$interface" --no-pager | grep -F "$network"
}

function unit-inactive() {
  test "$(systemctl show "$unit" -p ActiveState --value)" = inactive
}

function reset::link() {
  systemctl stop "$unit"
  systemctl reset-failed
  rm -f "$cache" "$network"
  ip link set "$interface" down
}

# the ENI is visible before its tag: stay pending in the same process without
# caching, and resolve once the tag shows up.
systemctl start --no-block "$unit"
wait::until ownership-pending
pending_pid=$(systemctl show "$unit" -p MainPID --value)
sleep 6
test "$(systemctl show "$unit" -p MainPID --value)" = "$pending_pid"
test "$(systemctl show "$unit" -p NRestarts --value)" = 0
assert::file-not-exists "$cache"
assert::file-not-exists "$network"
timeout 3 systemctl stop "$unit"
assert::file-not-exists "$cache"
systemctl start --no-block "$unit"
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
wait::until test -f "$network"
wait::until systemctl is-active --quiet "$unit"
assert::file-contains "$cache" '"mac":"0e:49:61:0f:c3:11"'
assert::file-contains "$cache" "io.systemd.Network"
assert::file-contains "$network" "RouteMetric=512"
wait::until networkd-selected-config

# an explicit negative tag is a CNI decision.
reset::link
aws ec2 create-tags --resources "$eni_id" --tags Key=node.k8s.amazonaws.com/no_manage,Value=false
systemctl start "$unit"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# a different ENI reusing the name does not inherit the cached decision.
systemctl stop "$unit"
systemctl reset-failed
echo '{"mac":"02:00:00:00:00:09","manager":"cni"}' > "$cache"
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
systemctl start "$unit"
assert::file-contains "$cache" '"mac":"0e:49:61:0f:c3:11"'
assert::file-contains "$cache" "io.systemd.Network"
wait::until networkd-selected-config

# a link another manager already brought up is left alone, tag or not.
reset::link
ip link set "$interface" up
systemctl start "$unit"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# with the gate off the CNI decision needs no EC2 access.
reset::link
rm /run/nodeadm/os-managed-no-manage-enis
AWS_ENDPOINT_URL=http://localhost:5001 timeout 5 nodeadm-internal udev-net-manager --action add --interface "$interface"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# the production udev rules start a pending unit on add and stop it on remove.
# only the driver property comes from the fixture, real ENA supplies it.
mkdir -p /etc/udev/rules.d
cp /90-eks.rules /etc/udev/rules.d/90-eks.rules
cat << 'EOF' > /etc/udev/rules.d/89-test-ena.rules
SUBSYSTEM=="net", KERNEL=="nm-event", ENV{ID_NET_DRIVER}="ena"
EOF
udevadm control --reload
touch /run/nodeadm/os-managed-no-manage-enis
unit=udev-net-manager@nm-event.service
ip link add nm-event address 02:00:00:00:00:08 type dummy
udevadm trigger --action=add /sys/class/net/nm-event
udevadm settle
wait::until ownership-pending
assert::file-not-exists "/etc/eks/nodeadm/udev-net-manager/$instance_id/nm-event"
ip link delete nm-event
udevadm settle
wait::until unit-inactive
assert::file-not-exists "/etc/eks/nodeadm/udev-net-manager/$instance_id/nm-event"
