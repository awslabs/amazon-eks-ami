#!/bin/bash

if [[ "$ENABLE_FLUENCE_KERNEL_MODULES" == "true" ]]; then
  echo "Set load kernel modules needed by fluence operations"
#   sudo touch /etc/modules-load.d/fluence.conf
  sudo echo "nf_nat_ftp" >> /etc/modules-load.d/fluence.conf
fi
