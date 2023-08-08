#!/usr/bin/env bash
export SCRIPTPATH="$(
  cd "$(dirname "$0")"
  pwd -P
)"
set -euo pipefail

TEST_CASE_SCRIPT=""

USAGE=$(
  cat << 'EOM'
  Usage: test-harness.sh  [-c <case script path>]
  Executes the test harness for the EKS Optimized AL2 AMI.
  By default the test harness executes all scripts in the cases directory.
  Example: test-harness.sh
          Optional:
            -c          A path to a specific test case script
EOM
)

while getopts "c:h" opt; do
  case ${opt} in
    c) # Case Script Path
      TEST_CASE_SCRIPT="$OPTARG"
      ;;
    h) # help
      echo "$USAGE" 1>&2
      exit
      ;;
    \?)
      echo "$USAGE" 1>&2
      exit
      ;;
  esac
done

docker build -t eks-optimized-ami -f "${SCRIPTPATH}/Dockerfile" "${SCRIPTPATH}/../"
overall_status=0

test_run_log_file=$(mktemp)

function run() {
  docker run -v "$(realpath $1):/test.sh" \
    --attach STDOUT \
    --attach STDERR \
    --rm \
    eks-optimized-ami > $test_run_log_file 2>&1
}

if [[ ! -z ${TEST_CASE_SCRIPT} ]]; then
  test_cases=${TEST_CASE_SCRIPT}
else
  test_cases=($(find ${SCRIPTPATH}/cases -name "*.sh" -type f))
fi

for case in "${test_cases[@]}"; do
  status=0
  echo "================================================================================================================="
  echo "-> Executing Test Case: $(basename ${case})"
  run ${case} || status=1
  if [[ ${status} -eq 0 ]]; then
    echo "✅ ✅ $(basename ${case}) Tests Passed! ✅ ✅"
  else
    cat $test_run_log_file
    echo "❌ ❌ $(basename ${case}) Tests Failed! ❌ ❌"
    overall_status=1
  fi
  echo "================================================================================================================="
done

if [[ ${overall_status} -eq 0 ]]; then
  echo "✅ ✅ All Tests Passed! ✅ ✅"
else
  echo "❌ ❌ Some Tests Failed! ❌ ❌"
fi
exit $overall_status
