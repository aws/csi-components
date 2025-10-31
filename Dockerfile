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

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.25@sha256:6bac879c5b77e0fc9c556a5ed8920e89dab1709bd510a854903509c828f67f96 AS builder
RUN go env -w GOCACHE=/gocache GOMODCACHE=/gomodcache
ARG GOPROXY
# Dependencies not in builder image: yq and go-licenses
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/mikefarah/yq/v4@latest
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/google/go-licenses@latest

WORKDIR /app/
COPY . .
ARG BUILD_PLATFORMS
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache make bin/$ENTRYPOINT

# Our base image, which is Amazon Linux based, automatically includes relevant licenses for the OS dependencies
# However, the go dependencies may generated additional license requires, which we copy to the final image
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache cd /app/build/$ENTRYPOINT && go-licenses save ./... --save_path /app/licenses/

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest-al23@sha256:26b66e6dbd1b2fe93487c4ecc01ff8d69d9c2be2faaece061a44ad4e3eacee6c AS linux-al2023
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT
COPY --from=builder /app/licenses/ /licenses/
ENTRYPOINT ["/$ENTRYPOINT"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:1809@sha256:517651cbf291f9e38da7e06a415dbd71860a77977ff127b32be856e7594e2052 AS windows-ltsc2019
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2022@sha256:3dda26d0d133bad3fe1edfb10ad3d98149e5504e27cc15bd4a4bed1042c483ca AS windows-ltsc2022
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]
