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

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.27@sha256:5f1b98fa02fe396ebce2a0227a0e08309e11792915b9dd2e1f71053d7e7e6666 AS builder
RUN go env -w GOCACHE=/gocache GOMODCACHE=/gomodcache
ARG GOPROXY
# Dependencies not in builder image: yq and go-licenses
RUN --mount=type=cache,target=/gomodcache --mount=type=cache,target=/gocache go install github.com/mikefarah/yq/v4@v4.54.3
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

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest-al23@sha256:4ed6077a5bf19fd7f882b53d04d1c18e8635512435ef0699e46a3feeb780916c AS linux-al2023
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT
COPY --from=builder /app/licenses/ /licenses/
ENV GODEBUG=fips140=off
ENTRYPOINT ["/$ENTRYPOINT"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:1809@sha256:13003564f90ad02c3e75f463cef9a2634fc52036c9ff41d291a53b5e7dab5eca AS windows-ltsc2019
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENV GODEBUG=fips140=off
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2022@sha256:d0823369e0f5d4f5a943c2ff3d4d1ff12ecef38f1ea8488ef785680ebfca4581 AS windows-ltsc2022
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENV GODEBUG=fips140=off
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2025@sha256:de7d5fb011ca4b9f1e924906839569bc8043d309248897325526302d887dcb4a AS windows-ltsc2025
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENV GODEBUG=fips140=off
ENTRYPOINT ["/$ENTRYPOINT.exe"]
