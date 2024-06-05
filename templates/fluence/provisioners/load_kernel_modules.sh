#!/bin/bash

if [[ "$ENABLE_FLUENCE_KERNEL_MODULES" == "true" ]]; then
  echo "Load kernel modules needed by fluence operations"
  #sudo yum install kmod
  sudo modprobe nf_nat_ftp
  echo "Check what kernel modules are loaded"
  sudo lsmod
fi
