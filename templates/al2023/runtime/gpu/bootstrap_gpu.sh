#!/bin/bash

NVIDIA_CLOCK_INIT_PATH="/etc/eks/initialize_nvidia_clock.sh"
NVIDIA_KMOD_LOAD_PATH="/etc/eks/nvidia-kmod-load.sh"

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

load_kernel_module() {
    log "Loading Nvidia Kernel Module..."
    $NVIDIA_KMOD_LOAD_PATH
    if [[ $? -ne 0 ]]; then
        log "Error loading Nvidia Kernel Module"
        exit 1
    fi
}

initialize_nvidia_clock() {
    log "Initializing Nvidia clock via shell..."
    $NVIDIA_CLOCK_INIT_PATH
    if [[ $? -ne 0 ]]; then
        log "Error initializing Nvidia clock"
        exit 1
    fi
}

load_kernel_module
initialize_nvidia_clock
