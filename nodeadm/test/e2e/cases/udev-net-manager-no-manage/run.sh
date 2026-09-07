#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh
mock::aws
mock::kubelet 1.34.0
wait::dbus-ready

# Use a distinct, initially down link and expose secondary ENI metadata for it.
# Moto's pinned ENI MAC matches this link; the proxy supplies device index 1.
interface=nm-test
ip link add "$interface" address 0e:49:61:0f:c3:11 type dummy
python3 imds.py &
wait::server-responding localhost 1339 10
export AWS_EC2_METADATA_SERVICE_ENDPOINT=http://localhost:1339
instance_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)
eni_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId' --output text)
cache=/etc/eks/nodeadm/udev-net-manager/$instance_id/$interface
network=/run/systemd/network/70-eks-$interface.network
unit=udev-net-manager@$interface.service
no_manage_tag="Key=node.k8s.amazonaws.com/no_manage,Value=true"

# Exercise the real NodeConfig -> run-phase marker integration.
nodeadm init --daemon="" --config-source file://config.yaml
test -f /run/nodeadm/init
test -f /run/nodeadm/os-managed-no-manage-enis

# Use the production unit and retry timing. Only the executable path and AWS
# endpoints differ in the harness.
ln -s /usr/local/bin/nodeadm-internal /usr/bin/nodeadm-internal
cp /udev-net-manager@.service /etc/systemd/system/
mkdir -p /etc/systemd/system/udev-net-manager@.service.d
env | grep '^AWS_' > /run/net-manager-test.env
cat > /etc/systemd/system/udev-net-manager@.service.d/test.conf << 'EOF'
[Service]
EnvironmentFile=/run/net-manager-test.env
EOF
systemctl daemon-reload
systemctl start systemd-udevd
udevadm trigger --action=add "/sys/class/net/$interface"
udevadm settle
# Dummy links do not expose an ENA permanent MAC. Restrict this fixture's
# generated network to its name so real networkd selection can be exercised.
mkdir -p "$network.d"
cat > "$network.d/10-test-match.conf" << EOF
[Match]
PermanentMACAddress=
Name=$interface
EOF
systemctl start systemd-networkd
test "$(systemctl show "$unit" -p RestartUSec --value)" = 1s
test "$(systemctl show "$unit" -p TimeoutStartUSec --value)" = infinity

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
  journalctl -u "$unit" --no-pager | grep -q "ENI or ownership tag not yet visible"
}

function reset::link() {
  systemctl stop "$unit"
  # Independent scenarios reuse one interface faster than real attachments.
  systemctl reset-failed
  rm -f "$cache" "$network"
  ip link set "$interface" down
}

# EC2 sees the ENI before its tags: remain uncached and keep the same process
# waiting, then recover automatically when the tag becomes visible.
systemctl start --no-block "$unit"
wait::until ownership-pending
pending_pid=$(systemctl show "$unit" -p MainPID --value)
sleep 12
test "$(systemctl show "$unit" -p MainPID --value)" = "$pending_pid"
test "$(systemctl show "$unit" -p NRestarts --value)" = 0
assert::file-not-exists "$cache"
assert::file-not-exists "$network"
# Stopping while waiting cancels promptly, without persisting a decision.
timeout 3 systemctl stop "$unit"
assert::file-not-exists "$cache"
systemctl start --no-block "$unit"
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
wait::until test -f "$network"
wait::until systemctl is-active --quiet "$unit"
assert::file-contains "$cache" "io.systemd.Network"
assert::file-contains "$network" "RouteMetric=513"
assert::file-contains "$network" "Table=10001"
assert::file-contains "$network" "From=172.16.34.44"
assert::file-contains "$cache" '"mac":"0e:49:61:0f:c3:11"'
# Observe networkd itself, not only the rendered file. DHCP acquisition still
# requires a real ENI and is covered by the live EKS validation.
function networkd-selected-config() {
  /usr/bin/networkctl status "$interface" --no-pager | grep -F "$network"
}
wait::until networkd-selected-config

# An explicit negative ownership tag is a definitive CNI decision.
reset::link
aws ec2 create-tags --resources "$eni_id" --tags Key=node.k8s.amazonaws.com/no_manage,Value=false
systemctl start "$unit"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# A different ENI reusing the same name must not inherit the CNI decision.
# Seed an old identity; keep the current link down and opt it out explicitly.
systemctl stop "$unit"
systemctl reset-failed
echo '{"mac":"02:00:00:00:00:09","manager":"cni"}' > "$cache"
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
systemctl start "$unit"
assert::file-contains "$cache" '"mac":"0e:49:61:0f:c3:11"'
assert::file-contains "$cache" "io.systemd.Network"
wait::until networkd-selected-config

# The reverse replacement must discard the old systemd file and ownership.
systemctl stop "$unit"
systemctl reset-failed
ip link set "$interface" down
echo '{"mac":"02:00:00:00:00:09","manager":"io.systemd.Network"}' > "$cache"
sed -i 's/0e:49:61:0f:c3:11/02:00:00:00:00:09/' "$network"
aws ec2 create-tags --resources "$eni_id" --tags Key=node.k8s.amazonaws.com/no_manage,Value=false
systemctl start "$unit"
assert::file-contains "$cache" '"manager":"cni"'
assert::file-not-exists "$network"

# Never adopt a link another manager has already brought up, even if an
# opt-out tag subsequently appears.
reset::link
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
ip link set "$interface" up
systemctl start "$unit"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# Disabling through NodeConfig removes the marker. An unreachable EC2
# endpoint must not prevent the feature-off decision on a down interface.
reset::link
sed 's/OSManagedNoManageENIs: true/OSManagedNoManageENIs: false/' config.yaml > /run/config-disabled.yaml
nodeadm init --daemon="" --config-source file:///run/config-disabled.yaml
assert::file-not-exists /run/nodeadm/os-managed-no-manage-enis
AWS_ENDPOINT_URL=http://localhost:5001 timeout 5 nodeadm-internal udev-net-manager --action add --interface "$interface"
assert::file-contains "$cache" "cni"
assert::file-not-exists "$network"

# Exercise the production add/remove rules on a separate dummy link. Only the
# driver property is supplied by the fixture; real ENA supplies it itself.
mkdir -p /etc/udev/rules.d
cp /90-eks.rules /etc/udev/rules.d/90-eks.rules
cat > /etc/udev/rules.d/89-test-ena.rules << 'EOF'
SUBSYSTEM=="net", KERNEL=="nm-event", ENV{ID_NET_DRIVER}="ena"
EOF
udevadm control --reload
touch /run/nodeadm/os-managed-no-manage-enis
event_unit=udev-net-manager@nm-event.service
ip link add nm-event address 02:00:00:00:00:08 type dummy
udevadm trigger --action=add /sys/class/net/nm-event
udevadm settle
function event-ownership-pending() {
  journalctl -u "$event_unit" --no-pager | grep -q "ENI or ownership tag not yet visible"
}
wait::until event-ownership-pending
assert::file-not-exists "/etc/eks/nodeadm/udev-net-manager/$instance_id/nm-event"
# A stale generated file must be removed along with the detached device.
touch /run/systemd/network/70-eks-nm-event.network
ip link delete nm-event
udevadm settle
function event-stopped() {
  [ "$(systemctl show "$event_unit" -p ActiveState --value)" = inactive ]
}
wait::until event-stopped
assert::file-not-exists /run/systemd/network/70-eks-nm-event.network
rm -f /run/nodeadm/os-managed-no-manage-enis
