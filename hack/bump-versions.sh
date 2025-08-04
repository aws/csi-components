#!/usr/bin/env bash

# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

set -euo pipefail
BASE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
IMAGES=$(yq '. | keys | join(" ")' "${BASE_DIR}/static-config.yaml")

for IMAGE in $IMAGES; do
  LATEST_RELEASE_URL="$(yq ".${IMAGE}.repo" "${BASE_DIR}/static-config.yaml" | sed 's|github.com/|api.github.com/repos/|')/releases/latest"
  CURRENT_TAG="$(yq ".${IMAGE}.tag" "${BASE_DIR}/release-config.yaml")"

  # Although the output of the GitHub API is JSON, use yq to not add a new dependency
  LATEST_TAG="$(curl -s "${LATEST_RELEASE_URL}" | yq '.tag_name')"
  yq -i ".${IMAGE}.tag=\"${LATEST_TAG}\"" "${BASE_DIR}/release-config.yaml"

  if [[ "${CURRENT_TAG}" == "${LATEST_TAG}" ]]; then
    CURRENT_EKSBUILD="$(yq ".${IMAGE}.eksbuild" "${BASE_DIR}/release-config.yaml")"
    NEW_EKSBUILD="$((CURRENT_EKSBUILD+1))"
  else
    NEW_EKSBUILD="1"
  fi
  yq -i ".${IMAGE}.eksbuild=\"${NEW_EKSBUILD}\"" "${BASE_DIR}/release-config.yaml"
done
