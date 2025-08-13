#!/usr/bin/env bash

set -o nounset

WORKDIR=$(realpath .)

SHFMT_COMMAND=$(which shfmt 2> /dev/null)
if [ -z "${SHFMT_COMMAND}" ]; then
  SHFMT_COMMAND="docker run --rm -v ${WORKDIR}:${WORKDIR} -w ${WORKDIR} mvdan/shfmt"
fi

${SHFMT_COMMAND} "$@"
