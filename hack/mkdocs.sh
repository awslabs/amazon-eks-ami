#!/usr/bin/env bash

set -o errexit

cd $(dirname $0)

IMAGE_ID=$(docker build --file mkdocs.Dockerfile --quiet .)
cd ..

if [[ "$*" =~ "serve" ]]; then
  EXTRA_ARGS="${EXTRA_ARGS} -a 0.0.0.0:8000"
fi

docker run --rm -v ${PWD}:/workdir -p 8000:8000 ${IMAGE_ID} "${@}" ${EXTRA_ARGS}
