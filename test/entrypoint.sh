#!/usr/bin/env bash
set -euo pipefail
SCRIPTPATH="$(
  cd "$(dirname "$0")"
  pwd -P
)"

## Start IMDS mock
/sbin/ec2-metadata-mock --imdsv2 &> /var/log/ec2-metadata-mock.log &
sleep 1

## execute any other params
/test.sh
