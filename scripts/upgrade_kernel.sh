#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

sudo yum update -y kernel

if [[ "$ENABLE_FIPS_MODE" == "true" ]]; then

  # install and enable fips modules
  sudo yum install -y dracut-fips openssl
  sudo dracut -f

  # enable fips in the boot command
  sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)"$/\1 fips=1"/' /etc/default/grub

  # rebuild grub
  sudo grub2-mkconfig -o /etc/grub2.cfg

  # reboot instance
  sudo reboot

fi

sudo reboot
