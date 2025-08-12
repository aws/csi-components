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
TEST="${1}"

IMAGES=$(yq '. | keys | join(" ")' "${BASE_DIR}/static-config.yaml")

# If repo already exists, instead fetch and checkout the tag
if [ -d "${BASE_DIR}/../build/aws-ebs-csi-driver" ]; then
  (cd "${BASE_DIR}/../build/aws-ebs-csi-driver" && git fetch origin "${E2E_EBS_CSI_VERSION}" && git reset --hard && git checkout "${E2E_EBS_CSI_VERSION}")
else
  git clone "https://github.com/kubernetes-sigs/aws-ebs-csi-driver.git" "${BASE_DIR}/../build/aws-ebs-csi-driver" --depth 1 --branch "${E2E_EBS_CSI_VERSION}"
fi

for IMAGE in $IMAGES; do
  EKSBUILD="$(yq ".${IMAGE}.eksbuild" "${BASE_DIR}/release-config.yaml")"
  PARAM=$(yq ".${IMAGE}.e2e-parameter" "${BASE_DIR}/static-config.yaml")
  if [ "${PARAM}" = "null" ]; then
    # Skip images with no e2e-parameter such as snapshot-controller
    continue
  fi
  TAG=${TAG_PREFIX}$(yq ".${IMAGE}.tag" "${BASE_DIR}/release-config.yaml")

  # TODO: Consider updating the aws-ebs-csi-driver repo to make this easier
  yq -i ".${PARAM}.repository=\"${REGISTRY}/${IMAGE}\"" "${BASE_DIR}/../build/aws-ebs-csi-driver/charts/aws-ebs-csi-driver/values.yaml"
  yq -i ".${PARAM}.tag=\"${TAG}-eksbuild.${EKSBUILD}\"" "${BASE_DIR}/../build/aws-ebs-csi-driver/charts/aws-ebs-csi-driver/values.yaml"
  yq -i ".${PARAM}.pullPolicy=\"Always\"" "${BASE_DIR}/../build/aws-ebs-csi-driver/charts/aws-ebs-csi-driver/values.yaml"
done

# Special case: snapshot-controller is not a sidecar, and is passed to the EBS CSI
# E2E tests through the environment variable EBS_INSTALL_SNAPSHOT_CUSTOM_IMAGE
SC_EKSBUILD="$(yq ".snapshot-controller.eksbuild" "${BASE_DIR}/release-config.yaml")"
export EBS_INSTALL_SNAPSHOT_CUSTOM_IMAGE="${REGISTRY}/${IMAGE}:${TAG_PREFIX}$(yq ".snapshot-controller.tag" "${BASE_DIR}/release-config.yaml")-eksbuild.${SC_EKSBUILD}"
# Use a KOPS bucket specifically for the CSI components, as to not conflict
# with any other clusters or E2E tests
export KOPS_BUCKET="$(aws sts get-caller-identity --query Account --output text)-csi-components-e2e"
(cd "${BASE_DIR}/../build/aws-ebs-csi-driver" && make "${TEST}")
