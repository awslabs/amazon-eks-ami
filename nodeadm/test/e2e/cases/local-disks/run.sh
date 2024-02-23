#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

nodeadm init --skip run --config-source file://config.yaml

assert::file-contains /etc/systemd/system/setup-local-disks.service.d/00-strategy.conf 'Environment=LOCAL_DISK_STRATEGY=raid0'
