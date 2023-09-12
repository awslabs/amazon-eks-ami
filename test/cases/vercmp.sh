#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should compare strictly less-than"
# should succeed
EXIT_CODE=0
vercmp "1.0.0" lt "2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" lt "1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" lt "1.1.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" lt "v1.1.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
# should fail
EXIT_CODE=0
vercmp "1.0.0" lt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.1" lt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.1.0" lt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "2.0.0" lt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v2.0.0" lt "v1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi

echo "--> Should compare less-than-or-equal-to"
# should succeed
EXIT_CODE=0
vercmp "1.0.0" lteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" lteq "1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" lteq "2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" lteq "v2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
# should fail
EXIT_CODE=0
vercmp "1.0.1" lteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.1.0" lteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "2.0.0" lteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v2.0.0" lteq "v1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi

echo "--> Should compare strictly equal-to"
# should succeed
EXIT_CODE=0
vercmp "1.0.0" eq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" eq "v1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
# should fail
EXIT_CODE=0
vercmp "1.0.1" eq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" eq "1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" eq "v1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi

echo "--> Should compare greater-than-or-equal-to"
# should succeed
EXIT_CODE=0
vercmp "1.0.0" gteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.1" gteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "2.0.0" gteq "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v2.0.0" gteq "v1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
# should fail
EXIT_CODE=0
vercmp "1.0.0" gteq "1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" gteq "1.1.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" gteq "2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" gteq "v2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi

echo "--> Should compare strictly greater-than"
# should succeed
EXIT_CODE=0
vercmp "2.0.0" gt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.1" gt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.1.0" gt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.1.0" gt "v1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
# should fail
EXIT_CODE=0
vercmp "1.0.0" gt "1.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" gt "1.0.1" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" gt "1.1.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "1.0.0" gt "2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
EXIT_CODE=0
vercmp "v1.0.0" gt "v2.0.0" || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${EXIT_CODE}'"
  exit 1
fi
