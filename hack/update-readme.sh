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
  TAG=$(yq ".${IMAGE}.tag" "${BASE_DIR}/release-config.yaml")
  EKSBUILD="$(yq ".${IMAGE}.eksbuild" "${BASE_DIR}/release-config.yaml")"
  sed -i -E "/${IMAGE}/s/v[0-9\\.]+-eksbuild\\.[0-9]+/${TAG}-eksbuild.${EKSBUILD}/g" "${BASE_DIR}/../README.md"
done
