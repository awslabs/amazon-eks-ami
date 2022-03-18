#!/usr/bin/env bash

### fetching sandbox image from /etc/containerd/config.toml
sandbox_image=$(awk -F'[ ="]+' '$1 == "sandbox_image" { print $2 }' /etc/containerd/config.toml)
region=$(echo "$sandbox_image" | cut -f4 -d ".")
ecr_password=$(aws ecr get-login-password --region $region)
API_RETRY_ATTEMPTS=5

for attempt in `seq 0 $API_RETRY_ATTEMPTS`; do
	rc=0
    if [[ $attempt -gt 0 ]]; then
        echo "Attempt $attempt of $API_RETRY_ATTEMPTS"
    fi
	### pull sandbox image from ecr
	### username will always be constant i.e; AWS
	sudo ctr --namespace k8s.io image pull $sandbox_image --user AWS:$ecr_password
	rc=$?;
	if [[ $rc -eq 0 ]]; then
		break
	fi
	if [[ $attempt -eq $API_RETRY_ATTEMPTS ]]; then
        exit $rc
    fi
    jitter=$((1 + RANDOM % 10))
    sleep_sec="$(( $(( 5 << $((1+$attempt)) )) + $jitter))"
    sleep $sleep_sec
done
