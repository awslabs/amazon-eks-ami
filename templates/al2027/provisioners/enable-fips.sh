#!/usr/bin/env bash

if [[ "$ENABLE_FIPS" == "true" ]]; then
  # https://docs.aws.amazon.com/linux/al2023/ug/fips-mode.html
  sudo dnf -y install crypto-policies crypto-policies-scripts
  sudo fips-mode-setup --enable
fi
