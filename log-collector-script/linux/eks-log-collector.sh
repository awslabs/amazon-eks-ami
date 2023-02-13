#!/usr/bin/env bash
# Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
#       http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# This script generates a file in go with the license contents as a constant

# Set language to C to make sorting consistent among different environments.

export LANG="C"
export LC_ALL="C"

# Global options
readonly PROGRAM_VERSION="0.7.3"
readonly PROGRAM_SOURCE="https://github.com/awslabs/amazon-eks-ami/blob/master/log-collector-script/"
readonly PROGRAM_NAME="$(basename "$0" .sh)"
readonly PROGRAM_DIR="/opt/log-collector"
readonly LOG_DIR="/var/log"
readonly COLLECT_DIR="/tmp/eks-log-collector"
readonly CURRENT_TIME=$(date --utc +%Y-%m-%d_%H%M-%Z)
readonly DAYS_10=$(date -d "-10 days" '+%Y-%m-%d %H:%M')
INSTANCE_ID=""
INIT_TYPE=""
PACKAGE_TYPE=""

# Script run defaults
ignore_introspection='false'
ignore_metrics='false'

REQUIRED_UTILS=(
  timeout
  curl
  tar
  date
  mkdir
  grep
  awk
  df
  sysctl
)

COMMON_DIRECTORIES=(
  kernel
  system
  docker
  containerd
  storage
  var_log
  networking
  sandbox-image # eks
  ipamd         # eks
  sysctls       # eks
  kubelet       # eks
  cni           # eks
)

COMMON_LOGS=(
  syslog
  messages
  aws-routed-eni # eks
  containers     # eks
  pods           # eks
  cloud-init.log
  cloud-init-output.log
  kube-proxy.log
)

# L-IPAMD introspection data points
IPAMD_DATA=(
  enis
  pods
  networkutils-env-settings
  ipamd-env-settings
  eni-configs
)

help() {
  echo ""
  echo "USAGE: ${PROGRAM_NAME} --help [ --ignore_introspection=true|false --ignore_metrics=true|false ]"
  echo ""
  echo "OPTIONS:"
  echo ""
  echo "   --ignore_introspection To ignore introspection of IPAMD; Pass this flag if DISABLE_INTROSPECTION is enabled on CNI"
  echo ""
  echo "   --ignore_metrics Variable To ignore prometheus metrics collection; Pass this flag if DISABLE_METRICS enabled on CNI"
  echo ""
  echo "   --help  Show this help message."
  echo ""
}

parse_options() {
  local count="$#"

  for i in $(seq "${count}"); do
    eval arg="\$$i"
    param="$(echo "${arg}" | awk -F '=' '{print $1}' | sed -e 's|--||')"
    val="$(echo "${arg}" | awk -F '=' '{print $2}')"

    case "${param}" in
      ignore_introspection)
        eval "${param}"="${val}"
        ;;
      ignore_metrics)
        eval "${param}"="${val}"
        ;;
      help)
        help && exit 0
        ;;
      *)
        echo "Parameter not found: '$param'"
        help && exit 1
        ;;
    esac
  done
}

ok() {
  echo
}

try() {
  local action=$*
  echo -n "Trying to $action... "
}

warning() {
  local reason=$*
  echo -e "\n\n\tWarning: $reason "
}

die() {
  echo -e "\n\tFatal Error! $* Exiting!\n"
  exit 1
}

is_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die "This script must be run as root!"
  fi
}

check_required_utils() {
  for utils in ${REQUIRED_UTILS[*]}; do
    # If exit code of "command -v" not equal to 0, fail
    if ! command -v "${utils}" > /dev/null 2>&1; then
      echo -e "\nApplication \"${utils}\" is missing, please install \"${utils}\" as this script requires it."
    fi
  done
}

version_output() {
  echo -e "\n\tThis is version ${PROGRAM_VERSION}. New versions can be found at ${PROGRAM_SOURCE}\n"
}

log_parameters() {
  echo ignore_introspection: "${ignore_introspection}" >> "${COLLECT_DIR}"/system/script-params.txt
  echo ignore_metrics: "${ignore_metrics}" >> "${COLLECT_DIR}"/system/script-params.txt
}

systemd_check() {
  if command -v systemctl > /dev/null 2>&1; then
    INIT_TYPE="systemd"
    if command -v snap > /dev/null 2>&1; then
      INIT_TYPE="snap"
    fi
  else
    INIT_TYPE="other"
  fi
}

# Get token for IMDSv2 calls
IMDS_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 360")

create_directories() {
  # Make sure the directory the script lives in is there. Not an issue if
  # the EKS AMI is used, as it will have it.
  mkdir -p "${PROGRAM_DIR}"

  # Common directories creation
  for directory in ${COMMON_DIRECTORIES[*]}; do
    mkdir -p "${COLLECT_DIR}"/"${directory}"
  done
}

get_instance_id() {
  INSTANCE_ID_FILE="/var/lib/cloud/data/instance-id"

  if grep -q '^i-' "$INSTANCE_ID_FILE"; then
    cp ${INSTANCE_ID_FILE} "${COLLECT_DIR}"/system/instance-id.txt
    readonly INSTANCE_ID=$(cat "${COLLECT_DIR}"/system/instance-id.txt)
  else
    readonly INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -f -s --max-time 10 --retry 5 http://169.254.169.254/latest/meta-data/instance-id)
    if [ 0 -eq $? ]; then # Check if previous command was successful.
      echo "${INSTANCE_ID}" > "${COLLECT_DIR}"/system/instance-id.txt
    else
      warning "Unable to find EC2 Instance Id. Skipped Instance Id."
    fi
  fi
}

get_region() {
  if REGION=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -f -s --max-time 10 --retry 5 http://169.254.169.254/latest/meta-data/placement/region); then
    echo "${REGION}" > "${COLLECT_DIR}"/system/region.txt
  else
    warning "Unable to find EC2 Region, skipping."
  fi

  if AZ=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" -f -s --max-time 10 --retry 5 http://169.254.169.254/latest/meta-data/placement/availability-zone); then
    echo "${AZ}" > "${COLLECT_DIR}"/system/availability-zone.txt
  else
    warning "Unable to find EC2 AZ, skipping."
  fi
}

is_diskfull() {
  local threshold
  local result

  # 1.5GB in KB
  threshold=1500000
  result=$(timeout 75 df / | grep --invert-match "Filesystem" | awk '{ print $4 }')

  # If "result" is less than or equal to "threshold", fail.
  if [[ "${result}" -le "${threshold}" ]]; then
    die "Free space on root volume is less than or equal to $((threshold >> 10))MB, please ensure adequate disk space to collect and store the log files."
  fi
}

cleanup() {
  #guard rails to avoid accidental deletion of unknown data
  if [[ "${COLLECT_DIR}" == "/tmp/eks-log-collector" ]]; then
    rm --recursive --force "${COLLECT_DIR}" > /dev/null 2>&1
  else
    echo "Unable to Cleanup as {COLLECT_DIR} variable is modified. Please cleanup manually!"
  fi
}

init() {
  check_required_utils
  version_output
  create_directories
  # Log parameters passed when this script is invoked
  log_parameters
  is_root
  systemd_check
  get_pkgtype
}

collect() {
  init
  is_diskfull
  get_instance_id
  get_region
  get_common_logs
  get_kernel_info
  get_mounts_info
  get_selinux_info
  get_iptables_info
  get_pkglist
  get_system_services
  get_containerd_info
  get_docker_info
  get_k8s_info
  get_ipamd_info
  get_multus_info
  get_sysctls_info
  get_networking_info
  get_cni_config
  get_docker_logs
  get_sandboxImage_info
  get_cpu_throttled_processes
  get_io_throttled_processes
}

pack() {
  try "archive gathered information"

  tar --create --verbose --gzip --file "${LOG_DIR}"/eks_"${INSTANCE_ID}"_"${CURRENT_TIME}"_"${PROGRAM_VERSION}".tar.gz --directory="${COLLECT_DIR}" . > /dev/null 2>&1

  ok
}

finished() {
  cleanup
  echo -e "\n\tDone... your bundled logs are located in ${LOG_DIR}/eks_${INSTANCE_ID}_${CURRENT_TIME}_${PROGRAM_VERSION}.tar.gz\n"
}

get_mounts_info() {
  try "collect mount points and volume information"
  mount > "${COLLECT_DIR}"/storage/mounts.txt
  echo >> "${COLLECT_DIR}"/storage/mounts.txt
  timeout 75 df --human-readable >> "${COLLECT_DIR}"/storage/mounts.txt
  timeout 75 df --inodes >> "${COLLECT_DIR}"/storage/inodes.txt
  lsblk > "${COLLECT_DIR}"/storage/lsblk.txt
  lvs > "${COLLECT_DIR}"/storage/lvs.txt
  pvs > "${COLLECT_DIR}"/storage/pvs.txt
  vgs > "${COLLECT_DIR}"/storage/vgs.txt
  mount -t xfs | awk '{print $1}' | xargs -I{} -- sh -c "xfs_info {}; xfs_db -r -c 'freesp -s' {}" > "${COLLECT_DIR}"/storage/xfs.txt
  mount | grep ^overlay | sed 's/.*upperdir=//' | sed 's/,.*//' | xargs -n 1 timeout 75 du -sh | grep -v ^0 > "${COLLECT_DIR}"/storage/pod_local_storage.txt
  ok
}

get_selinux_info() {
  try "collect SELinux status"

  if ! command -v getenforce > /dev/null 2>&1; then
    echo -e "SELinux mode:\n\t Not installed" > "${COLLECT_DIR}"/system/selinux.txt
  else
    echo -e "SELinux mode:\n\t $(getenforce)" > "${COLLECT_DIR}"/system/selinux.txt
  fi

  ok
}

get_iptables_info() {
  if ! command -v iptables > /dev/null 2>&1; then
    echo "IPtables not installed" | tee -a iptables.txt
  else
    try "collect iptables information"
    iptables --wait 1 --numeric --verbose --list --table mangle | tee "${COLLECT_DIR}"/networking/iptables-mangle.txt | sed '/^num\|^$\|^Chain\|^\ pkts.*.destination/d' | echo -e "=======\nTotal Number of Rules: $(wc -l)" >> "${COLLECT_DIR}"/networking/iptables-mangle.txt
    iptables --wait 1 --numeric --verbose --list --table filter | tee "${COLLECT_DIR}"/networking/iptables-filter.txt | sed '/^num\|^$\|^Chain\|^\ pkts.*.destination/d' | echo -e "=======\nTotal Number of Rules: $(wc -l)" >> "${COLLECT_DIR}"/networking/iptables-filter.txt
    iptables --wait 1 --numeric --verbose --list --table nat | tee "${COLLECT_DIR}"/networking/iptables-nat.txt | sed '/^num\|^$\|^Chain\|^\ pkts.*.destination/d' | echo -e "=======\nTotal Number of Rules: $(wc -l)" >> "${COLLECT_DIR}"/networking/iptables-nat.txt
    iptables --wait 1 --numeric --verbose --list | tee "${COLLECT_DIR}"/networking/iptables.txt | sed '/^num\|^$\|^Chain\|^\ pkts.*.destination/d' | echo -e "=======\nTotal Number of Rules: $(wc -l)" >> "${COLLECT_DIR}"/networking/iptables.txt
    iptables-save > "${COLLECT_DIR}"/networking/iptables-save.txt
  fi

  ok
}

get_common_logs() {
  try "collect common operating system logs"

  for entry in ${COMMON_LOGS[*]}; do
    if [[ -e "/var/log/${entry}" ]]; then
      if [[ "${entry}" == "messages" ]]; then
        tail -c 100M /var/log/messages > "${COLLECT_DIR}"/var_log/messages
        continue
      fi
      if [[ "${entry}" == "containers" ]]; then
        cp --force --dereference --recursive /var/log/containers/aws-node* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/containers/kube-system_cni-metrics-helper* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/containers/coredns-* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/containers/kube-proxy* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/containers/ebs-csi* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/containers/efs-csi* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        continue
      fi
      if [[ "${entry}" == "pods" ]]; then
        cp --force --dereference --recursive /var/log/pods/kube-system_aws-node* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/pods/kube-system_cni-metrics-helper* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/pods/kube-system_coredns* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/pods/kube-system_kube-proxy* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/pods/kube-system_ebs-csi-* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        cp --force --dereference --recursive /var/log/pods/kube-system_efs-csi-* "${COLLECT_DIR}"/var_log/ 2> /dev/null
        continue
      fi
      cp --force --recursive --dereference /var/log/"${entry}" "${COLLECT_DIR}"/var_log/ 2> /dev/null
    fi
  done

  ok
}

get_kernel_info() {
  try "collect kernel logs"

  if [[ -e "/var/log/dmesg" ]]; then
    cp --force /var/log/dmesg "${COLLECT_DIR}/kernel/dmesg.boot"
  fi
  dmesg > "${COLLECT_DIR}/kernel/dmesg.current"
  dmesg --ctime > "${COLLECT_DIR}/kernel/dmesg.human.current"
  uname -a > "${COLLECT_DIR}/kernel/uname.txt"

  ok
}

get_docker_logs() {
  try "collect Docker daemon logs"

  case "${INIT_TYPE}" in
    systemd | snap)
      journalctl --unit=docker --since "${DAYS_10}" > "${COLLECT_DIR}"/docker/docker.log
      ;;
    other)
      for entry in docker upstart/docker; do
        if [[ -e "/var/log/${entry}" ]]; then
          cp --force --recursive --dereference /var/log/"${entry}" "${COLLECT_DIR}"/docker/
        fi
      done
      ;;
    *)
      warning "The current operating system is not supported."
      ;;
  esac

  ok
}

get_k8s_info() {
  try "collect kubelet information"

  if [[ -n "${KUBECONFIG:-}" ]]; then
    command -v kubectl > /dev/null && kubectl get --kubeconfig="${KUBECONFIG}" svc > "${COLLECT_DIR}"/kubelet/svc.log
    command -v kubectl > /dev/null && kubectl --kubeconfig="${KUBECONFIG}" config view --output yaml > "${COLLECT_DIR}"/kubelet/kubeconfig.yaml

  elif [[ -f /etc/eksctl/kubeconfig.yaml ]]; then
    KUBECONFIG="/etc/eksctl/kubeconfig.yaml"
    command -v kubectl > /dev/null && kubectl get --kubeconfig="${KUBECONFIG}" svc > "${COLLECT_DIR}"/kubelet/svc.log
    command -v kubectl > /dev/null && kubectl --kubeconfig="${KUBECONFIG}" config view --output yaml > "${COLLECT_DIR}"/kubelet/kubeconfig.yaml

  elif [[ -f /etc/systemd/system/kubelet.service ]]; then
    KUBECONFIG=$(grep kubeconfig /etc/systemd/system/kubelet.service | awk '{print $2}')
    command -v kubectl > /dev/null && kubectl get --kubeconfig="${KUBECONFIG}" svc > "${COLLECT_DIR}"/kubelet/svc.log
    command -v kubectl > /dev/null && kubectl --kubeconfig="${KUBECONFIG}" config view --output yaml > "${COLLECT_DIR}"/kubelet/kubeconfig.yaml

  elif [[ -f /var/lib/kubelet/kubeconfig ]]; then
    KUBECONFIG="/var/lib/kubelet/kubeconfig"
    command -v kubectl > /dev/null && kubectl get --kubeconfig=${KUBECONFIG} svc > "${COLLECT_DIR}"/kubelet/svc.log
    command -v kubectl > /dev/null && kubectl --kubeconfig=${KUBECONFIG} config view --output yaml > "${COLLECT_DIR}"/kubelet/kubeconfig.yaml

  else
    echo "======== Unable to find KUBECONFIG, IGNORING POD DATA =========" >> "${COLLECT_DIR}"/kubelet/svc.log
  fi

  # Try to copy the kubeconfig file if kubectl command doesn't exist
  [[ (! -f "${COLLECT_DIR}/kubelet/kubeconfig.yaml") && (-n ${KUBECONFIG}) ]] && cp ${KUBECONFIG} "${COLLECT_DIR}"/kubelet/kubeconfig.yaml

  case "${INIT_TYPE}" in
    systemd)
      timeout 75 journalctl --unit=kubelet --since "${DAYS_10}" > "${COLLECT_DIR}"/kubelet/kubelet.log

      systemctl cat kubelet > "${COLLECT_DIR}"/kubelet/kubelet_service.txt 2>&1
      ;;
    snap)
      timeout 75 snap logs kubelet-eks -n all > "${COLLECT_DIR}"/kubelet/kubelet.log

      timeout 75 snap get kubelet-eks > "${COLLECT_DIR}"/kubelet/kubelet-eks_service.txt 2>&1
      ;;
    *)
      warning "The current operating system is not supported."
      ;;
  esac

  ok
}

get_ipamd_info() {
  if [[ "${ignore_introspection}" == "false" ]]; then
    try "collect L-IPAMD introspection information"
    for entry in ${IPAMD_DATA[*]}; do
      curl --max-time 3 --silent http://localhost:61679/v1/"${entry}" >> "${COLLECT_DIR}"/ipamd/"${entry}".json
    done
  else
    echo "Ignoring IPAM introspection stats as mentioned" | tee -a "${COLLECT_DIR}"/ipamd/ipam_introspection_ignore.txt
  fi

  if [[ "${ignore_metrics}" == "false" ]]; then
    try "collect L-IPAMD prometheus metrics"
    curl --max-time 3 --silent http://localhost:61678/metrics > "${COLLECT_DIR}"/ipamd/metrics.json 2>&1
  else
    echo "Ignoring Prometheus Metrics collection as mentioned" | tee -a "${COLLECT_DIR}"/ipamd/ipam_metrics_ignore.txt
  fi

  try "collect L-IPAMD checkpoint"
  cp /var/run/aws-node/ipam.json "${COLLECT_DIR}"/ipamd/ipam.json

  ok
}

get_multus_info() {
  try "collect Multus logs if they exist"
  cp --force --dereference --recursive /var/log/pods/kube-system_kube-multus* "${COLLECT_DIR}"/var_log/ 2> /dev/null

  ok
}

get_sysctls_info() {
  try "collect sysctls information"
  # dump all sysctls
  sysctl --all >> "${COLLECT_DIR}"/sysctls/sysctl_all.txt 2> /dev/null

  ok
}

get_networking_info() {
  try "collect networking infomation"

  # conntrack info
  echo "*** Output of conntrack -S *** " >> "${COLLECT_DIR}"/networking/conntrack.txt
  timeout 75 conntrack -S >> "${COLLECT_DIR}"/networking/conntrack.txt
  echo "*** Output of conntrack -L ***" >> "${COLLECT_DIR}"/networking/conntrack.txt
  timeout 75 conntrack -L >> "${COLLECT_DIR}"/networking/conntrack.txt

  # ifconfig
  timeout 75 ifconfig > "${COLLECT_DIR}"/networking/ifconfig.txt

  # ip rule show
  timeout 75 ip rule show > "${COLLECT_DIR}"/networking/iprule.txt
  timeout 75 ip route show table all >> "${COLLECT_DIR}"/networking/iproute.txt

  # configure-multicard-interfaces
  timeout 75 journalctl -u configure-multicard-interfaces > "${COLLECT_DIR}"/networking/configure-multicard-interfaces.txt || echo -e "\tTimed out, ignoring \"configure-multicard-interfaces unit output \" "

  # test some network connectivity
  timeout 75 ping -A -c 10 amazon.com > "${COLLECT_DIR}"/networking/ping_amazon.com.txt
  timeout 75 ping -A -c 10 public.ecr.aws > "${COLLECT_DIR}"/networking/ping_public.ecr.aws.txt

  if [[ -e "${COLLECT_DIR}"/kubelet/kubeconfig.yaml ]]; then
    API_SERVER=$(grep server: "${COLLECT_DIR}"/kubelet/kubeconfig.yaml | sed 's/.*server: //')
    CA_CRT=$(grep certificate-authority: "${COLLECT_DIR}"/kubelet/kubeconfig.yaml | sed 's/.*certificate-authority: //')
    for i in $(seq 5); do
      echo -e "curling ${API_SERVER} ($i of 5) $(date --utc +%FT%T.%3N%Z)\n\n" >> ${COLLECT_DIR}"/networking/curl_api_server.txt"
      timeout 75 curl -v --cacert "${CA_CRT}" "${API_SERVER}"/livez?verbose >> ${COLLECT_DIR}"/networking/curl_api_server.txt" 2>&1
    done
  fi

  cp /etc/resolv.conf "${COLLECT_DIR}"/networking/resolv.conf
  ok
}

get_cni_config() {
  try "collect CNI configuration information"

  if [[ -e "/etc/cni/net.d/" ]]; then
    cp --force --recursive --dereference /etc/cni/net.d/* "${COLLECT_DIR}"/cni/
  fi

  ok
}

get_pkgtype() {
  if [[ "$(command -v rpm)" ]]; then
    PACKAGE_TYPE=rpm
  elif [[ "$(command -v dpkg)" ]]; then
    PACKAGE_TYPE=deb
  else
    PACKAGE_TYPE='unknown'
  fi
}

get_pkglist() {
  try "collect installed packages"

  case "${PACKAGE_TYPE}" in
    rpm)
      rpm -qa > "${COLLECT_DIR}"/system/pkglist.txt 2>&1
      ;;
    deb)
      dpkg --list > "${COLLECT_DIR}"/system/pkglist.txt 2>&1
      ;;
    *)
      warning "Unknown package type."
      ;;
  esac

  ok
}

get_system_services() {
  try "collect active system services"

  case "${INIT_TYPE}" in
    systemd | snap)
      systemctl list-units > "${COLLECT_DIR}"/system/services.txt 2>&1
      ;;
    other)
      initctl list | awk '{ print $1 }' | xargs -n1 initctl show-config > "${COLLECT_DIR}"/system/services.txt 2>&1
      printf "\n\n\n\n" >> "${COLLECT_DIR}"/system/services.txt 2>&1
      service --status-all >> "${COLLECT_DIR}"/system/services.txt 2>&1
      ;;
    *)
      warning "Unable to determine active services."
      ;;
  esac

  timeout 75 top -b -n 1 > "${COLLECT_DIR}"/system/top.txt 2>&1
  timeout 75 ps fauxwww --headers > "${COLLECT_DIR}"/system/ps.txt 2>&1
  timeout 75 ps -eTF --headers > "${COLLECT_DIR}"/system/ps-threads.txt 2>&1
  timeout 75 netstat -plant > "${COLLECT_DIR}"/system/netstat.txt 2>&1
  timeout 75 cat /proc/stat > "${COLLECT_DIR}"/system/procstat.txt 2>&1
  timeout 75 cat /proc/[0-9]*/stat > "${COLLECT_DIR}"/system/allprocstat.txt 2>&1

  ok
}

get_containerd_info() {
  try "Collect Containerd daemon information"

  if [[ "$(pgrep -o containerd)" -ne 0 ]]; then
    # force containerd to dump goroutines
    timeout 75 killall -sUSR1 containerd
    timeout 75 containerd config dump > "${COLLECT_DIR}"/containerd/containerd-config.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 journalctl -u containerd > "${COLLECT_DIR}"/containerd/containerd-log.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 cp -f /tmp/containerd.*.stacks.log "${COLLECT_DIR}"/containerd/
  else
    warning "The Containerd daemon is not running."
  fi

  ok

  try "Collect Containerd running information"
  if ! command -v ctr > /dev/null 2>&1; then
    warning "ctr not installed"
  else
    timeout 75 ctr version > "${COLLECT_DIR}"/containerd/containerd-version.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 ctr namespaces list > "${COLLECT_DIR}"/containerd/containerd-namespaces.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 ctr --namespace k8s.io images list > "${COLLECT_DIR}"/containerd/containerd-images.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 ctr --namespace k8s.io containers list > "${COLLECT_DIR}"/containerd/containerd-containers.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 ctr --namespace k8s.io tasks list > "${COLLECT_DIR}"/containerd/containerd-tasks.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
    timeout 75 ctr --namespace k8s.io plugins list > "${COLLECT_DIR}"/containerd/containerd-plugins.txt 2>&1 || echo -e "\tTimed out, ignoring \"containerd info output \" "
  fi

  ok
}

get_sandboxImage_info() {
  try "Collect sandbox-image daemon information"
  timeout 75 journalctl -u sandbox-image > "${COLLECT_DIR}"/sandbox-image/sandbox-image-log.txt 2>&1 || echo -e "\tTimed out, ignoring \"sandbox-image info output \" "
  ok
}

get_docker_info() {
  try "Collect Docker daemon information"

  if [[ "$(pgrep -o dockerd)" -ne 0 ]]; then
    timeout 75 docker info > "${COLLECT_DIR}"/docker/docker-info.txt 2>&1 || echo -e "\tTimed out, ignoring \"docker info output \" "
    timeout 75 docker ps --all --no-trunc > "${COLLECT_DIR}"/docker/docker-ps.txt 2>&1 || echo -e "\tTimed out, ignoring \"docker ps --all --no-truc output \" "
    timeout 75 docker images > "${COLLECT_DIR}"/docker/docker-images.txt 2>&1 || echo -e "\tTimed out, ignoring \"docker images output \" "
    timeout 75 docker version > "${COLLECT_DIR}"/docker/docker-version.txt 2>&1 || echo -e "\tTimed out, ignoring \"docker version output \" "
    timeout 75 curl --unix-socket /var/run/docker.sock http://./debug/pprof/goroutine\?debug\=2 > "${COLLECT_DIR}"/docker/docker-trace.txt 2>&1 || echo -e "\tTimed out, ignoring \"docker version output \" "
  else
    warning "The Docker daemon is not running."
  fi

  ok
}

get_cpu_throttled_processes() {
  try "Collect CPU Throttled Process Information"
  readonly THROTTLE_LOG="${COLLECT_DIR}"/system/cpu_throttling.txt
  command find /sys/fs/cgroup -iname "cpu.stat" -print0 | while IFS= read -r -d '' cs; do
    # look for a non-zero nr_throttled value
    if grep -q "nr_throttled [1-9]" "${cs}"; then
      pids=${cs/cpu.stat/cgroup.procs}
      lines=$(wc -l < "${pids}")
      # ignore if no PIDs are listed
      if [ "${lines}" -eq "0" ]; then
        continue
      fi

      echo "$cs" >> "${THROTTLE_LOG}"
      cat "${cs}" >> "${THROTTLE_LOG}"
      while IFS= read -r pid; do
        command ps ax | grep "^${pid}" >> "${THROTTLE_LOG}"
      done < "${pids}"
      echo "" >> "${THROTTLE_LOG}"
    fi
  done
  if [ ! -e "${THROTTLE_LOG}" ]; then
    echo "No CPU Throttling Found" >> "${THROTTLE_LOG}"
  fi
  ok
}

get_io_throttled_processes() {
  try "Collect IO Throttled Process Information"
  readonly IO_THROTTLE_LOG="${COLLECT_DIR}"/system/io_throttling.txt
  command echo -e "PID Name Block IO Delay (centisconds)" > ${IO_THROTTLE_LOG}
  # column 42 is Aggregated block I/O delays, measured in centiseconds so we capture the non-zero block
  # I/O delays.
  command cut -d" " -f 1,2,42 /proc/[0-9]*/stat | sort -n -k+3 -r | grep -v 0$ >> ${IO_THROTTLE_LOG}
  ok
}

# -----------------------------------------------------------------------------
# Entrypoint
parse_options "$@"

collect
pack
finished
