#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

if ! gpu-ami-util has-nvidia-devices; then
  echo >&2 "no NVIDIA devices are present, nothing to do!"
  exit 0
fi

# gpu boost clock
sudo nvidia-smi -pm 1 # set persistence mode
sudo nvidia-smi --auto-boost-default=0

GPUNAME=$(nvidia-smi -L | head -n1)
echo >&2 "INFO: GPU name: $GPUNAME"

# set application clock to maximum
if [[ $GPUNAME == *"A100"* ]]; then
  nvidia-smi -ac 1215,1410
elif [[ $GPUNAME == *"V100"* ]]; then
  nvidia-smi -ac 877,1530
elif [[ $GPUNAME == *"T4"* ]]; then
  nvidia-smi -ac 5001,1590
elif [[ $GPUNAME == *"H100"* ]]; then
  nvidia-smi -ac 2619,1980
elif [[ $GPUNAME == *"A10G"* ]]; then
  nvidia-smi -ac 6251,1695
elif [[ $GPUNAME == *"L4"* ]]; then
  nvidia-smi -ac 6251,2040
elif [[ $GPUNAME == *"L40S"* ]]; then
  nvidia-smi -ac 9001,2520
else
  echo "unsupported gpu"
fi
