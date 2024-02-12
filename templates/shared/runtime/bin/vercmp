#!/usr/bin/env bash

# Comparison expressions for semantic versions.
# only supports semver standard MAJOR.MINOR.PATCH syntax;
# pre-release or build-metadata extensions have undefined behavior.

set -o errexit
set -o pipefail

function usage() {
  echo "Comparison expressions for semantic versions."
  echo
  echo "usage: vercmp VERSION_A OPERATOR VERSION_B"
  echo
  echo "OPERATORS"
  echo
  echo "  lt   - Less than"
  echo "  lteq - Less than or equal to"
  echo "  eq   - Equal to"
  echo "  gteq - Grater than or equal to"
  echo "  gt   - Greater than"
  echo
}

if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

LEFT="$1"
OPERATOR="$2"
RIGHT="$3"

if [ "$LEFT" = "$RIGHT" ]; then
  COMPARISON=0
else
  SORTED=($(for VER in "$LEFT" "$RIGHT"; do echo "$VER"; done | sort -V))
  if [ "${SORTED[0]}" = "$LEFT" ]; then
    COMPARISON=-1
  else
    COMPARISON=1
  fi
fi

OUTCOME=false

case $OPERATOR in
  lt)
    if [ "$COMPARISON" -eq -1 ]; then
      OUTCOME=true
    fi
    ;;

  lteq)
    if [ "$COMPARISON" -lt 1 ]; then
      OUTCOME=true
    fi
    ;;

  eq)
    if [ "$COMPARISON" -eq 0 ]; then
      OUTCOME=true
    fi
    ;;

  gteq)
    if [ "$COMPARISON" -gt -1 ]; then
      OUTCOME=true
    fi
    ;;

  gt)
    if [ "$COMPARISON" -eq 1 ]; then
      OUTCOME=true
    fi
    ;;

  *)
    usage
    exit 1
    ;;
esac

VERCMP_QUIET="${VERCMP_QUIET:-false}"
if [ ! "$VERCMP_QUIET" = "true" ]; then
  echo "$OUTCOME"
fi

if [ "$OUTCOME" = "true" ]; then
  exit 0
else
  exit 1
fi
