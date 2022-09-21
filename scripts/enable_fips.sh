#!/bin/bash
# Install the necessary software and rebuild GRUB if we're instructed to enable FIPS support.
if [[ "$ENABLE_FIPS_MODE" == "true" ]]; then
  # install and enable fips modules
  sudo yum install -y dracut-fips openssl
  sudo dracut -f

  # enable fips in the boot command
  sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)"$/\1 fips=1"/' /etc/default/grub

  # rebuild grub
  sudo grub2-mkconfig -o /etc/grub2.cfg
fi

sudo reboot