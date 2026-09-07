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
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
wait::until test -f "$network"
wait::until systemctl is-active --quiet "$unit"
assert::file-contains "$cache" "io.systemd.Network"
assert::file-contains "$network" "RouteMetric=513"
assert::file-contains "$network" "Table=10001"
assert::file-contains "$network" "From=172.16.34.44"

# An explicit negative ownership tag is a definitive CNI decision.
reset::link
aws ec2 create-tags --resources "$eni_id" --tags Key=node.k8s.amazonaws.com/no_manage,Value=false
systemctl start "$unit"
assert::file-contains "$cache" "cni"
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
