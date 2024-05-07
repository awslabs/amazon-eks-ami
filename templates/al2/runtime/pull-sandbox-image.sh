#!/usr/bin/env bash

source <(grep "sandbox_image" /etc/containerd/config.toml | tr -d ' ')

### skip if we don't have a sandbox_image set in config.toml
if [[ -z ${sandbox_image:-} ]]; then
  echo >&2 "Skipping ... missing sandbox_image from /etc/containerd/config.toml"
  exit 0
fi

### Short-circuit fetching sandbox image if its already present
if [[ -n $(sudo ctr --namespace k8s.io image ls | grep "${sandbox_image}") ]]; then
  echo >&2 "Skipping ... sandbox_image '${sandbox_image}' is already present"
  exit 0
fi

# use the region that the sandbox image comes from for the ecr authentication,
# also mitigating the localzone isse: https://github.com/aws/aws-cli/issues/7043
region=$(echo "${sandbox_image}" | cut -f4 -d ".")

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

# for public, non-ecr repositories even if this fails to get ECR credentials the image will pull
ecr_password=$(retry aws ecr get-login-password --region "${region}")
if [[ -z ${ecr_password} ]]; then
  echo >&2 "Unable to retrieve the ECR password. Image pull may not be properly authenticated."
fi
retry sudo crictl pull --creds "AWS:${ecr_password}" "${sandbox_image}"
