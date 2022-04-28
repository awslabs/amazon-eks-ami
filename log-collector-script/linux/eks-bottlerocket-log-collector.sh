export LANG="C"
export LC_ALL="C"

# Global options
BOTTLEROCKET_ROOTFS="/.bottlerocket/rootfs"
readonly CURRENT_TIME=$(date --utc +%Y-%m-%d_%H%M-%Z)
readonly PROGRAM_VERSION="0.6.2"
readonly LOG_DIR="/var/log"
INSTANCE_ID=""

BOTTLEROCKET_UTILS=(
  tar 
)

is_diskfull() {
  local threshold
  local result

  # 1.5GB in KB
  threshold=1500000
  result=$(df / | grep --invert-match "Filesystem" | awk '{ print $4 }')

  # If "result" is less than or equal to "threshold", fail.
  if [[ "${result}" -le "${threshold}" ]]; then
    die "Free space on root volume is less than or equal to $((threshold>>10))MB, please ensure adequate disk space to collect and store the log files."
  fi
}

collect_logs_bottlerocket() {
  echo "Fetching INSTANCE_ID"
  readonly INSTANCE_ID=$(curl --max-time 10 --retry 5 http://169.254.169.254/latest/meta-data/instance-id)
  if [ 0 -eq $? ]; then # Check if previous command was successful.
    echo "${INSTANCE_ID}"
  else
    warning "Unable to find EC2 Instance Id. Skipped Instance Id."
  fi
  
  if [ ! -d "${BOTTLEROCKET_ROOTFS}/tmp/ekslogs" ]; then
     echo "Creating ekslogs directory"
     mkdir ${BOTTLEROCKET_ROOTFS}/tmp/ekslogs
  fi

  for utils in ${BOTTLEROCKET_UTILS[*]}; do
    # If exit code of "command -v" not equal to 0, fail
    if ! command -v "${utils}" >/dev/null 2>&1; then
       echo -e "\nApplication \"${utils}\" is missing, will install \"${utils}\"."
       sudo yum install -y "${utils}"
    fi
  done

  cp ${BOTTLEROCKET_ROOTFS}/var/log/aws-routed-eni/* ${BOTTLEROCKET_ROOTFS}/tmp/ekslogs/
  sudo sheltie logdog
  sudo sheltie cp /var/log/support/bottlerocket-logs.tar.gz /tmp/ekslogs
  tar -cvzf "${LOG_DIR}"/eks_"${INSTANCE_ID}"_"${CURRENT_TIME}"_"${PROGRAM_VERSION}".tar.gz "${BOTTLEROCKET_ROOTFS}"/tmp/ekslogs > /dev/null 2>&1
}

finished() {
  cleanup
  echo -e "\n\tDone... your bundled logs are located in ${LOG_DIR}/eks_${INSTANCE_ID}_${CURRENT_TIME}_${PROGRAM_VERSION}.tar.gz\n"
}

cleanup() {
  # bottlerocket AMI
  if [ -d "/.bottlerocket/" ]; then
    rm --recursive --force {BOTTLEROCKET_ROOTFS}/tmp/ekslogs > /dev/null 2>&1  
  else
    echo "Unable to Cleanup as {COLLECT_DIR} variable is modified. Please cleanup manually!"
  fi
}

echo "Detected Bottlerocket AMI"
is_diskfull
collect_logs_bottlerocket
finished