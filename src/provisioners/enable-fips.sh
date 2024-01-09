#!/bin/bash

if [[ "$ENABLE_FIPS" == "true" ]]; then
  if [[ "$OS_DISTRO" == "al2" ]]; then
    # https://aws.amazon.com/blogs/publicsector/enabling-fips-mode-amazon-linux-2/
    # install and enable fips modules
    sudo yum install -y dracut-fips openssl
    sudo dracut -f
    # enable fips in the boot command
    sudo /sbin/grubby --update-kernel=ALL --args="fips=1"
  elif [[ "$OS_DISTRO" == "al2023" ]]; then
    # https://docs.aws.amazon.com/linux/al2023/ug/fips-mode.html
    sudo dnf -y install crypto-policies crypto-policies-scripts
    sudo fips-mode-setup --enable
  fi
fi
