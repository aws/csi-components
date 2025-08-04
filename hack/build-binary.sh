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

BINARY="${1}"
REPO=$(yq ".${BINARY}.repo" "${BASE_DIR}/static-config.yaml")
TAG=$(yq ".${BINARY}.tag" "${BASE_DIR}/release-config.yaml")
EKSBUILD="$(yq ".${BINARY}.eksbuild" "${BASE_DIR}/release-config.yaml")"

# If repo already exists, instead fetch and checkout the tag
if [ -d "${BASE_DIR}/../build/${BINARY}" ]; then
  (cd "${BASE_DIR}/../build/${BINARY}" && git fetch origin "${TAG}" && git reset --hard && git checkout "${TAG}")
else
  git clone "${REPO}" "${BASE_DIR}/../build/${BINARY}" --depth 1 --branch "${TAG}"
fi

# Apply patches
shopt -s nullglob # Ignore scenario when no patches to apply
for patch_file in ${BASE_DIR}/../patches/${BINARY}/*.patch; do
  git -C "${BASE_DIR}/../build/${BINARY}" apply "$patch_file"
done

# Apply version-only patches
for MODULE in $(yq ".${BINARY} | keys | join(\" \")" "${BASE_DIR}/../patches/dependency-patches.yaml"); do
  PATCH_VERSION=$(yq ".${BINARY}.[\"${MODULE}\"]" "${BASE_DIR}/../patches/dependency-patches.yaml")
  BASE_VERSION=$(cd "${BASE_DIR}/../build/${BINARY}" && go list -m -json "${MODULE}" | yq '.Version')
  # Credit: Modified version of https://stackoverflow.com/a/4024263
  if [ "${PATCH_VERSION}" = "$(echo -e "${PATCH_VERSION}\n${BASE_VERSION}" | sort -V | head -n1)" ]; then
    echo -e "\\033[0;31m${MODULE} patch was not an upgrade! (${BASE_VERSION} -> ${PATCH_VERSION})\\033[0m"
    exit 1
  fi
  # Must tidy & vendor to avoid breaking future calls to go list
  (cd "${BASE_DIR}/../build/${BINARY}" && go get "${MODULE}@${PATCH_VERSION}" && go mod tidy && go mod vendor)
done

# Build binary, copy to top-level bin
(cd "${BASE_DIR}/../build/${BINARY}" && go mod tidy && go mod vendor && go mod download)
# csi-release-utils requires arguments *as an argument to make*
# Passing arguments as environment variables won't work!
make -C "${BASE_DIR}/../build/${BINARY}" BUILD_PLATFORMS="${BUILD_PLATFORMS}" REV="${TAG}-eksbuild.${EKSBUILD}"
cp "${BASE_DIR}/../build/${BINARY}/bin/${BINARY}" "${BASE_DIR}/../bin/${BINARY}"
