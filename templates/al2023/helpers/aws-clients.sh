#!/usr/bin/env bash
#
# Wrappers around the AWS CLI for build-time downloads.

# Runs `aws s3` with the given arguments, retrying unsigned if the signed request fails,
# so public buckets stay reachable when the build instance has no credentials.
function aws_s3() {
  if ! aws s3 "$@"; then
    echo >&2 "aws s3 ${1} failed, retrying with an unsigned request"
    aws --no-sign-request s3 "$@"
  fi
}
