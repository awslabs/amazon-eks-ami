#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

AWS_DOMAIN=$(imds 'latest/meta-data/services/domain')
ECR_URI="$(/etc/eks/get-ecr-uri.sh ${AWS_REGION} ${AWS_DOMAIN})"
cache-pause-container "${ECR_URI}/eks/pause:3.5"
