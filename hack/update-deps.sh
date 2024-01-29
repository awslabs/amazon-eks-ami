#!/usr/bin/env bash

# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash

set -o errexit
set -o pipefail

# The first argument is the path, defaulting to the current directory if not provided
TARGET_DIR="${1:-.}"

# Update the main project dependencies
cd "${TARGET_DIR}"
go get $(go list -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' -mod=mod -m all)
go mod tidy

# Update dependencies in the e2e test directory
if [ -d "${TARGET_DIR}/test/e2e" ]; then
  cd "${TARGET_DIR}/test/e2e"
  go mod tidy
else
  echo "e2e test directory does not exist"
fi
