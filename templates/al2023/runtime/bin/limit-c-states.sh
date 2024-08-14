#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

if [ "$ACCELERATOR_VENDOR" == "neuron" ] || [ "$ACCELERATOR_VENDOR" == "nvidia" ]; then
    echo "Limiting deeper C-states"
    sudo grubby \
        --update-kernel=ALL \
        --args="intel_idle.max_cstate=1 processor.max_cstate=1"
fi