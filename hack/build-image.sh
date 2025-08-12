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

# Enter base of repo
cd "${BASE_DIR}/.."

TARGETS=$(yq ".${IMAGE}.targets | join(\" \")" "${BASE_DIR}/static-config.yaml")
TAG=${TAG_PREFIX}$(yq ".${IMAGE}.tag" "${BASE_DIR}/release-config.yaml")
EKSBUILD="$(yq ".${IMAGE}.eksbuild" "${BASE_DIR}/release-config.yaml")"

# Check if image already exists and skip the build if so
# Must delete local copy if exists so the check always hits the remote registry
docker manifest rm "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}" &>/dev/null || true
IMAGE_CHECK="$(docker manifest inspect "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}" 2>&1 && echo "Image found in registry" || true)"
if [[ "${IMAGE_CHECK}" == *"Image found in registry" ]]; then
  echo "Skipping ${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD} - already exists in registry"
  exit 0
elif [[ "${IMAGE_CHECK}" == "no such manifest"* ]]; then
  echo "Building ${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}"
else
  echo "Failed to check registry for ${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}"
  echo "${IMAGE_CHECK}"
  exit 1
fi

# Build Dockerfile from template
# Because Docker doesn't support arguments in the ENTRYPOINT, we must
# template a Dockerfile for each image using external tools like sed
cp "Dockerfile" "Dockerfile.${IMAGE}"
sed -i "s/\$ENTRYPOINT/${IMAGE}/g" "Dockerfile.${IMAGE}"

# Build each subimage with a specific ARCH/OS/OSVERSION set
IMAGES=()
for TARGET in $TARGETS; do
  ARCH=$(cut -d '-' -f 1 <<<$TARGET)
  OS=$(cut -d '-' -f 2 <<<$TARGET)
  OSVERSION=$(cut -d '-' -f 3 <<<$TARGET)

  docker buildx build \
    --platform="${OS}/${ARCH}" \
    --progress=plain \
    --target="${OS}-${OSVERSION}" \
    --output=type=registry \
    -t="${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}-${OS}-${ARCH}-${OSVERSION}" \
    --build-arg="GOPROXY=${GOPROXY:-}" \
    --build-arg="BUILD_PLATFORMS=${OS} ${ARCH}" \
    --provenance=false \
    -f "Dockerfile.${IMAGE}" \
    .
  IMAGES+=("${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}-${OS}-${ARCH}-${OSVERSION}")
done

# Push combined manifest with all architecture/OS-specific subimagse
docker manifest create --amend "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}" "${IMAGES[@]}"
docker manifest push --purge "${REGISTRY}/${IMAGE}:${TAG}-eksbuild.${EKSBUILD}"
