#!/bin/bash
# https://aws.amazon.com/blogs/publicsector/enabling-fips-mode-amazon-linux-2/
if [[ "$ENABLE_FIPS" == "true" ]]; then
  # install and enable fips modules
  sudo yum install -y dracut-fips openssl
  sudo dracut -f

  # enable fips in the boot command
  sudo /sbin/grubby --update-kernel=ALL --args="fips=1"
fi
