#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

if ! gpu-ami-util has-nvidia-devices; then
  echo >&2 "no NVIDIA devices are present, nothing to do!"
  exit 0
fi

# gpu boost clock
if command -v nvidia-smi &> /dev/null; then
  echo >&2 "INFO: nvidia-smi found"

  nvidia-smi -q > /tmp/nvidia-smi-check
  if [[ "$?" == "0" ]]; then
    sudo nvidia-smi -pm 1 # set persistence mode
    sudo nvidia-smi --auto-boost-default=0

    GPUNAME=$(nvidia-smi -L | head -n1)
    echo >&2 "INFO: GPU name: $GPUNAME"

    # set application clock to maximum
    if [[ $GPUNAME == *"A100"* ]]; then
      nvidia-smi -ac 1215,1410
    elif [[ $GPUNAME == *"V100"* ]]; then
      nvidia-smi -ac 877,1530
    elif [[ $GPUNAME == *"K80"* ]]; then
      nvidia-smi -ac 2505,875
    elif [[ $GPUNAME == *"T4"* ]]; then
      nvidia-smi -ac 5001,1590
    elif [[ $GPUNAME == *"M60"* ]]; then
      nvidia-smi -ac 2505,1177
    elif [[ $GPUNAME == *"H100"* ]]; then
      nvidia-smi -ac 2619,1980
    else
      echo "unsupported gpu"
    fi
  else
    echo >&2 "ERROR: nvidia-smi check failed!"
    cat /tmp/nvidia-smi-check
  fi
fi

