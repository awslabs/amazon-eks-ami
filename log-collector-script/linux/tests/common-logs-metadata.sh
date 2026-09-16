#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(mktemp -d)"
cleanup_test_root() {
  rm -rf "${TEST_ROOT}"
}
trap cleanup_test_root EXIT

# shellcheck source=../eks-log-collector.sh
source "${SCRIPT_DIR}/../eks-log-collector.sh"

common_log_root="${TEST_ROOT}/var-log"
collect_dir="${TEST_ROOT}/collect"
source_dir="${common_log_root}/aws-routed-eni"
destination_dir="${collect_dir}/var_log/aws-routed-eni"
mkdir -p "${source_dir}" "${collect_dir}/var_log"

printf '%s' '{"component":"aws-vpc-cni","marker":"cni bytes"}' \
  > "${source_dir}/aws-vpc-cni-metadata.json"
printf '%s' '{"component":"aws-network-policy-agent","marker":"npa bytes"}' \
  > "${source_dir}/aws-network-policy-agent-metadata.json"

get_common_logs "${common_log_root}" "${collect_dir}" > /dev/null

cmp \
  "${source_dir}/aws-vpc-cni-metadata.json" \
  "${destination_dir}/aws-vpc-cni-metadata.json"
cmp \
  "${source_dir}/aws-network-policy-agent-metadata.json" \
  "${destination_dir}/aws-network-policy-agent-metadata.json"
