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

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.27@sha256:f44f6e88636cfb311f9ebace870ded69d943f227bb3cb27d32ffd84ea18c43ea AS builder
RUN go env -w GOCACHE=/gocache GOMODCACHE=/gomodcache
ARG GOPROXY
# Dependencies not in builder image: yq and go-licenses
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/mikefarah/yq/v4@v4.53.6
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/google/go-licenses/v2@v2.0.1

WORKDIR /app/
COPY . .
ARG BUILD_PLATFORMS
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache make bin/$ENTRYPOINT

# Our base image, which is Amazon Linux based, automatically includes relevant licenses for the OS dependencies
# However, the go dependencies may generated additional license requires, which we copy to the final image
# GOFLAGS=-mod=mod works around https://github.com/google/go-licenses/issues/310 (vendor + local replace)
# The for loop copies the root LICENSE into local replace targets that lack their own LICENSE file
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache cd /app/build/$ENTRYPOINT && \
    for d in $(sed -n 's|.*=> \./\([^[:space:]]*\).*|\1|p' go.mod); do if [ -d "$d" ] && [ ! -f "$d/LICENSE" ] && [ -f LICENSE ]; then cp LICENSE "$d/LICENSE"; fi; done && \
    export GOFLAGS=-mod=mod && \
    go-licenses save $(go list ./...) --save_path /app/licenses/

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest-al23@sha256:4349948c5668dc3efaf531abed381197c4c8759d380aec1877e9adc61b45820a AS linux-al2023
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT
COPY --from=builder /app/licenses/ /licenses/
ENTRYPOINT ["/$ENTRYPOINT"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:1809@sha256:b4e46d9241a95ccc50ef73123714acb295472737a01cba52577dab153fdadf49 AS windows-ltsc2019
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2022@sha256:75f0e07262f526660444f06f5b27c834580802808489a8e6f2b7f6db11310571 AS windows-ltsc2022
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2025@sha256:d9c384028f72213ede7e69bd473e1dc24b35e4f9538eb4d829b02492393a3fb9 AS windows-ltsc2025
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]
