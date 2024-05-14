#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

function assert::files-equal() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: assert::files-equal FILE1 FILE2"
    exit 1
  fi
  local FILE1=$1
  local FILE2=$2
  if ! diff $FILE1 $FILE2; then
    echo "Files $FILE1 and $FILE2 are not equal"
    exit 1
  fi
}

function assert::json-files-equal() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: assert::json-files-equal FILE1 FILE2"
    exit 1
  fi
  local FILE1=$1
  stat $FILE1
  local FILE2=$2
  stat $FILE2
  if ! diff <(jq -S . $FILE1) <(jq -S . $FILE2); then
    echo "Files $FILE1 and $FILE2 are not equal"
    exit 1
  fi
}

function assert::file-contains() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: assert::file-contains FILE PATTERN"
    exit 1
  fi
  local FILE=$1
  local PATTERN=$2
  if ! grep -e "$PATTERN" $FILE; then
    echo "File $FILE does not contain pattern '$PATTERN'"
    cat $FILE
    echo ""
    exit 1
  fi
}

function assert::file-not-contains() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: assert::file-not-contains FILE PATTERN"
    exit 1
  fi
  local FILE=$1
  local PATTERN=$2
  if grep -e "$PATTERN" $FILE; then
    echo "File $FILE contains pattern '$PATTERN'"
    cat $FILE
    echo ""
    exit 1
  fi
}

function mock::kubelet() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: mock::kubelet VERSION"
    exit 1
  fi
  printf "#!/usr/bin/env bash\necho Kubernetes v%s\n" "$1" > /usr/bin/kubelet
  chmod +x /usr/bin/kubelet
}

function mock::setup-local-disks() {
  mkdir -p /var/log
  printf '#!/usr/bin/env bash\necho "$1" >> /var/log/setup-local-disks.log' > /usr/bin/setup-local-disks
  chmod +x /usr/bin/setup-local-disks
}

function wait::path-exists() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: wait::path-exists TARGET_PATH"
    return 1
  fi
  local TARGET_PATH=$1
  local TIMEOUT=10
  local INTERVAL=1
  local ELAPSED=0
  while ! stat $TARGET_PATH; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
      echo "Timed out waiting for $TARGET_PATH"
      return 1
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
  done
}

function wait::dbus-ready() {
  wait::path-exists /run/systemd/private
}

function mock::aws() {
  local CONFIG_PATH=${1:-/etc/aemm-default-config.json}
  [ "${IMDS_MOCK_ONLY_CONFIGURE:-}" = "true" ] || imds-mock --config-file $CONFIG_PATH &
  export AWS_EC2_METADATA_SERVICE_ENDPOINT=http://localhost:1338
  [ "${AWS_MOCK_ONLY_CONFIGURE:-}" = "true" ] || $HOME/.local/bin/moto_server -p5000 &
  export AWS_ACCESS_KEY_ID='testing'
  export AWS_SECRET_ACCESS_KEY='testing'
  export AWS_SECURITY_TOKEN='testing'
  export AWS_SESSION_TOKEN='testing'
  export AWS_REGION=us-east-1
  export AWS_ENDPOINT_URL=http://localhost:5000
  # ensure that our instance exists in the API
  aws ec2 run-instances
}
