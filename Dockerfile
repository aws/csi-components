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

FROM --platform=$BUILDPLATFORM public.ecr.aws/docker/library/golang:1.24@sha256:7161c5d38baf03b46026405fbd52be79ccd678dd1dc648367a1e4dcbf45ccf2b AS builder
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

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-minimal-base:latest-al23@sha256:f8f1a278ff43373d1b9953337a78fdd1b69d7baacba1b4ecd26781330fc7e447 AS linux-al2023
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT
COPY --from=builder /app/licenses/ /licenses/
ENTRYPOINT ["/$ENTRYPOINT"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:1809@sha256:78c9b45225cb88900c9303b671a68f66b281350c5e2a16e96285a54ffb1183a6 AS windows-ltsc2019
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]

FROM public.ecr.aws/eks-distro-build-tooling/eks-distro-windows-base:ltsc2022@sha256:3b5cafc9e5ff95dbf53749df8c4c78381306218c36799fde50996276702c8454 AS windows-ltsc2022
COPY --from=builder /app/bin/$ENTRYPOINT /$ENTRYPOINT.exe
COPY --from=builder /app/licenses/ /licenses/
USER ContainerAdministrator
ENTRYPOINT ["/$ENTRYPOINT.exe"]
