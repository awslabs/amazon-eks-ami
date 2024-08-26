#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

if [ "$ENABLE_EFA" != "true" ]; then
  exit 0
fi

echo "Limiting deeper C-states"
sudo grubby \
  --update-kernel=ALL \
  --args="intel_idle.max_cstate=1 processor.max_cstate=1"
