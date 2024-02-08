#!/usr/bin/env bash

sed '/^$/N;/^\n$/D' "${1}" > "${1}.tmp"
mv "${1}.tmp" "${1}"
