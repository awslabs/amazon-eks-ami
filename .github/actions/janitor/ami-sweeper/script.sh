#!/usr/bin/env bash

set -o errexit
set -o pipefail

MAX_AGE_SECONDS=${MAX_AGE_SECONDS:-$1}
if [ -z "${MAX_AGE_SECONDS}" ]; then
  echo "usage: $0 MAX_AGE_SECONDS"
  exit 1
fi

set -o nounset

# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html
AWS_RETRY_MODE=standard
AWS_MAX_ATTEMPTS=5

function jqb64() {
  if [ "$#" -lt 2 ]; then
    echo "usage: jqb64 BASE64_JSON JQ_ARGS..."
    exit 1
  fi
  BASE64_JSON="$1"
  shift
  echo "$BASE64_JSON" | base64 --decode | jq "$@"
}
for IMAGE_DETAILS in $(aws ec2 describe-images --owners self --output json | jq -r '.Images[] | @base64'); do
  NAME=$(jqb64 "$IMAGE_DETAILS" -r '.Name')
  IMAGE_ID=$(jqb64 "$IMAGE_DETAILS" -r '.ImageId')
  CREATION_DATE=$(jqb64 "$IMAGE_DETAILS" -r '.CreationDate')
  CREATION_DATE_SECONDS=$(date -d "$CREATION_DATE" '+%s')
  CURRENT_TIME_SECONDS=$(date '+%s')
  MIN_CREATION_DATE_SECONDS=$(($CURRENT_TIME_SECONDS - $MAX_AGE_SECONDS))
  if [ "$CREATION_DATE_SECONDS" -lt "$MIN_CREATION_DATE_SECONDS" ]; then
    aws ec2 deregister-image --image-id "$IMAGE_ID"
    for SNAPSHOT_ID in $(jqb64 "$IMAGE_DETAILS" -r '.BlockDeviceMappings[].Ebs.SnapshotId'); do
      aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID"
    done
    echo "Deleted $IMAGE_ID: $NAME"
  fi
done
