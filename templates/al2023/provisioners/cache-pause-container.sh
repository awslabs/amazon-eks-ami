#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

cache-pause-container "$(nodeadm runtime ecr-uri)/eks/pause:3.5"
