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
IMAGE="${1}"
TAG=${TAG_PREFIX}$(yq ".${IMAGE}.tag" "${BASE_DIR}/release-config.yaml")
EKSBUILD="$(yq ".${IMAGE}.eksbuild" "${BASE_DIR}/release-config.yaml")"

# Pulling ensures we always have the latest image (Trivy will skip pull sometimes)
docker pull -q "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}"
if [ -n "${OUTPUT_SARIF:+x}" ]; then
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro public.ecr.aws/aquasecurity/trivy:latest image -f sarif "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}" > "${BASE_DIR}/../output/${IMAGE}.sarif"
  # Required by GitHub to upload multiple SARIF files: https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning#uploading-more-than-one-sarif-file-for-a-commit
  yq -o json -i ".runs[].automationDetails.id = \"trivy/${IMAGE}/$(date +%s)\"" "${BASE_DIR}/../output/${IMAGE}.sarif"
else
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro public.ecr.aws/aquasecurity/trivy:latest image -q "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}"
fi
