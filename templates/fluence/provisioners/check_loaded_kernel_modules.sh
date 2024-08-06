#!/bin/bash

if [[ "$ENABLE_FLUENCE_KERNEL_MODULES" == "true" ]]; then
  # call lsmod with sudo, otherwise there will be error that command is not found
  echo "Check what kernel modules are loaded"
  sudo lsmod
  echo "Check nat ftp module information"
  modinfo nf_nat_ftp
fi
