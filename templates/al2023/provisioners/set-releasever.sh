#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit

# NOTE to maintainers: this script be called at the beginning and the end of a build (sandwiching any package operations)

RELEASEVER_FILEPATH="/etc/dnf/vars/releasever"
LATEST_KEYWORD="latest"

# AL2023 uses a releasever concept for locking accessible packages.
# This is resolved in order of
# 1) value of the releasever flag passed to dnf
# 2) the contents the optiona value /etc/dnf/vars/releasever (default unset)
# 3) the installed version of system-release
# https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades-usage.html#using-a-deterministic-upgraded-system
if [ "${SET_DEFAULT_LATEST:-}" == "true" ]; then
    echo latest | sudo tee $RELEASEVER_FILEPATH
else 
    sudo rm -f $RELEASEVER_FILEPATH
fi
