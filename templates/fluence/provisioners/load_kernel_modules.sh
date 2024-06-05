#!/bin/bash

if [[ "$ENABLE_FLUENCE_KERNEL_MODULES" == "true" ]]; then
  echo "Load kernel modules needed by fluence operations"
  yum install kmod
  modprobe nf_nat_ftp
fi
