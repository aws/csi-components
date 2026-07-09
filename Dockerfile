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

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.26@sha256:079e59808d2d252516e27e3f3a9c003740dee7f75e55aa71528766d52bcfc16a AS builder
RUN go env -w GOCACHE=/gocache GOMODCACHE=/gomodcache
ARG GOPROXY
# Dependencies not in builder image: yq and go-licenses
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/mikefarah/yq/v4@v4.53.3
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

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest-al23@sha256:20f087a7e5d60be3037d20ce5c0d4c5fa0b22f57f246b6ca60296181bbe7b4c6 AS linux-al2023
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT
COPY --from=builder /app/licenses/ /licenses/
ENTRYPOINT ["/$ENTRYPOINT"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:1809@sha256:42e03d8f623138eeeba6be556456d90d7c3bd43f5013aed46213665613d7b474 AS windows-ltsc2019
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2022@sha256:401f3644d7be7da77b84a67a8752d6a7396f3c392d042afa5bbf2863bc270898 AS windows-ltsc2022
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2025@sha256:506605084e2233b2751c36b73dcc5eb3b8c203f168203762a7acf2ea0c5dbc4b AS windows-ltsc2025
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]
