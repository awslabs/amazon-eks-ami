#!/usr/bin/env bash

img=$1
region=$(echo "${img}" | cut -f4 -d ".")
MAX_RETRIES=3

function retry() {
  local rc=0
  for attempt in $(seq 0 $MAX_RETRIES); do
    rc=0
    [[ $attempt -gt 0 ]] && echo "Attempt $attempt of $MAX_RETRIES" 1>&2
    "$@"
    rc=$?
    [[ $rc -eq 0 ]] && break
    [[ $attempt -eq $MAX_RETRIES ]] && exit $rc
    local jitter=$((1 + RANDOM % 10))
    local sleep_sec="$(($((5 << $((1 + $attempt)))) + $jitter))"
    sleep $sleep_sec
  done
}

ecr_password=$(retry aws ecr get-login-password --region $region)
if [[ -z ${ecr_password} ]]; then
  echo >&2 "Unable to retrieve the ECR password."
  exit 1
fi
retry sudo ctr --namespace k8s.io content fetch "${img}" --user AWS:${ecr_password}
