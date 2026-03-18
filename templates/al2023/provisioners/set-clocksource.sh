#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# use the tsc clocksource by default
# https://repost.aws/knowledge-center/manage-ec2-linux-clock-source
sudo grubby \
  --update-kernel=ALL \
  --args="clocksource=tsc tsc=reliable"
