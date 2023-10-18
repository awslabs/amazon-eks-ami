#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd $(dirname $0)/..

OS=$(uname)
for FILE in $(find . -type f -not -path "*/.git/*"); do
  if git check-ignore --quiet "$FILE"; then
    continue
  fi
  if [ "$OS" = "Darwin" ]; then
    # macOS sed doesn't support '-i'
    sed 's/[[:space:]]*$//g' "$FILE" > "$FILE.tmp"
    # macOS chmod doesn't support '--reference'
    chmod "$(stat -f "%Mp%Lp" $FILE)" "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"
  else
    # assume we have a sane sed
    sed -i 's/[[:space:]]*$//g' "$FILE"
  fi
done
