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

## Configuration
# Registry - all images will be built to this registry suffixed with their name
# (e.g. csi-attacher will be pushed to $(REGISTRY)/csi-attacher)
REGISTRY?=$(shell aws sts get-caller-identity --query Account --output text).dkr.ecr.us-west-2.amazonaws.com
# Build platforms passed to csi-release-utils (this will typically be automatically set by build-image.sh)
BUILD_PLATFORMS?=linux amd64
# Version of EBS CSI Driver to use for E2E testing
# This should be a git tag or branch
E2E_EBS_CSI_VERSION?=release-1.47
# Tag prefix (used for CI)
TAG_PREFIX?=
# Files to rebuild when changed
BUILD_SOURCES=$(shell find hack/ patches/ -type f \( -iname "*.sh" -o -iname "*.yaml" \))
# Output Trivy in SARIF format (e.g. for GitHub upload)
OUTPUT_SARIF?=

## Default target
# When no target is supplied, make runs the first target that does not begin with a .
# Alias that to building all the images
.PHONY: default
default: all-image

## Top level targets

.PHONY: clean
clean:
	rm -rf bin/ build/ output/ Dockerfile.*

# Helper target to quickly create ECR repos
.PHONY: setup-ecr
setup-ecr:
	aws ecr create-repository --region us-west-2 --repository-name csi-attacher || true
	aws ecr create-repository --region us-west-2 --repository-name csi-node-driver-registrar || true
	aws ecr create-repository --region us-west-2 --repository-name csi-provisioner || true
	aws ecr create-repository --region us-west-2 --repository-name csi-resizer || true
	aws ecr create-repository --region us-west-2 --repository-name csi-snapshotter || true
	aws ecr create-repository --region us-west-2 --repository-name livenessprobe || true
	aws ecr create-repository --region us-west-2 --repository-name snapshot-controller || true

# Helper target to bump all images to the latest version
.PHONY: bump-versions
bump-versions:
	@hack/bump-versions.sh

# Helper target to update README information (such as images table)
.PHONY: update-readme
update-readme:
	@hack/update-readme.sh

# Output licenses for a given binary
# Requires https://github.com/google/go-licenses to be installed
licenses/%: bin/%
	cd ./build/$* && go-licenses report ./...

## Binary build targets

bin build output:
	@mkdir -p $@

bin/%: $(BUILD_SOURCES) | bin build
	@BUILD_PLATFORMS="$(BUILD_PLATFORMS)" hack/build-binary.sh $*

.PHONY: all
all: bin/csi-snapshotter bin/csi-attacher bin/csi-provisioner bin/csi-resizer bin/csi-node-driver-registrar bin/livenessprobe bin/snapshot-controller

## Container image targets

image/%: $(BUILD_SOURCES) Dockerfile .dockerignore
	@TAG_PREFIX="$(TAG_PREFIX)" REGISTRY="$(REGISTRY)" hack/build-image.sh $*

.PHONY: all-image
all-image: image/csi-snapshotter image/csi-attacher image/csi-provisioner image/csi-resizer image/csi-node-driver-registrar image/livenessprobe image/snapshot-controller

## Trivy (image scanner) targets

trivy/%: output
	@TAG_PREFIX="$(TAG_PREFIX)" REGISTRY="$(REGISTRY)" OUTPUT_SARIF="$(OUTPUT_SARIF)" hack/trivy.sh $*

.PHONY: all-trivy
all-trivy: trivy/csi-snapshotter trivy/csi-attacher trivy/csi-provisioner trivy/csi-resizer trivy/csi-node-driver-registrar trivy/livenessprobe trivy/snapshot-controller

## E2E targets

e2e/%: | build
	@TAG_PREFIX="$(TAG_PREFIX)" REGISTRY="$(REGISTRY)" E2E_EBS_CSI_VERSION="$(E2E_EBS_CSI_VERSION)" hack/e2e.sh $*
