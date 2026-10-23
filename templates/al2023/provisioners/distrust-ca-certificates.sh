#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# Certificates in /etc/pki/ca-trust/source/blocklist (staged from the rootfs) are distrusted
# by p11-kit. Regenerate the extracted bundles so clients that only read them stop trusting
# those certificates too.
#
# Blocked roots: emSign Root TLS CA - G3, emSign ECC Root CA - G3 and AAA Certificate Services,
# related to the eMudhra intermediate CA compromise of October 2026, plus emSign ECC Root CA - C3
# and emSign Root CA - C1, which eMudhra asked to be removed. Remove once the fixed
# ca-certificates package ships.
#   https://explore.alas.aws.amazon.com/CVE-2026-113470.html
#   https://explore.alas.aws.amazon.com/CVE-2026-111943.html
sudo update-ca-trust extract
