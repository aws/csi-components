# Components for CSI

[![E2E Tests](https://github.com/aws/csi-components/actions/workflows/e2e.yaml/badge.svg?event=push)](https://github.com/aws/csi-components/actions/workflows/e2e.yaml)
[![Push Staging Images](https://github.com/aws/csi-components/actions/workflows/release.yaml/badge.svg?event=push)](https://github.com/aws/csi-components/actions/workflows/release.yaml)
[![AWS Janitor](https://github.com/aws/csi-components/actions/workflows/janitor.yaml/badge.svg)](https://github.com/aws/csi-components/actions/workflows/janitor.yaml)

## Overview

This repository contains the tooling used to build minimal Amazon Linux based versions of the [Kubernetes CSI Sidecars](https://kubernetes-csi.github.io/docs/sidecar-containers.html) (and other related components such as the Kubernetes CSI `snapshot-controller` image).

These images are used in the official releases of the [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/) versions `v1.45.0` and later.

## Images

The released images are hosted on the [`csi-components` ECR Public Registry](https://gallery.ecr.aws/csi-components).

| Project | Latest Released Version | Image Pull URI |
| ------------- | ------------- | ------------- |
| [external-attacher](https://github.com/kubernetes-csi/external-attacher) | v4.10.0-eksbuild.4 | `public.ecr.aws/csi-components/csi-attacher:v4.10.0-eksbuild.4` |
| [node-driver-registrar](https://github.com/kubernetes-csi/node-driver-registrar) | v2.15.0-eksbuild.4 | `public.ecr.aws/csi-components/csi-node-driver-registrar:v2.15.0-eksbuild.4` |
| [external-provisioner](https://github.com/kubernetes-csi/external-provisioner) | v6.1.0-eksbuild.3 | `public.ecr.aws/csi-components/csi-provisioner:v6.1.0-eksbuild.3` |
| [external-resizer](https://github.com/kubernetes-csi/external-resizer) | v2.0.0-eksbuild.4 | `public.ecr.aws/csi-components/csi-resizer:v2.0.0-eksbuild.4` |
| [external-snapshotter](https://github.com/kubernetes-csi/external-snapshotter) | v8.4.0-eksbuild.4 | `public.ecr.aws/csi-components/csi-snapshotter:v8.4.0-eksbuild.4` |
| [livenessprobe](https://github.com/kubernetes-csi/livenessprobe) | v2.17.0-eksbuild.4 | `public.ecr.aws/csi-components/livenessprobe:v2.17.0-eksbuild.4` |
| [snapshot-controller](https://github.com/kubernetes-csi/external-snapshotter) | v8.4.0-eksbuild.4 | `public.ecr.aws/csi-components/snapshot-controller:v8.4.0-eksbuild.4` |

## Building

### Dependencies

The following dependencies are required to build:
- `yq`: https://github.com/mikefarah/yq
- `git`: https://git-scm.com/downloads
- `docker` and `docker buildx`: https://docs.docker.com/get-docker/ and https://github.com/docker/buildx#installing
- `make`
- `go`: https://go.dev/doc/install (only if building binaries locally or reporting licenses)
- `go-licenses`: https://github.com/google/go-licenses (only if reporting licenses)

### `make all`

`make all` will build all of the binaries that are used in each image, but not the images themselves.

`make bin/PROJECT` may be used to build an individual binary.

### `make all-images`

`make all-images` will build and push all images provided by this project. The `REGISTRY` environment variable can be used to set the destination registry.

`make image/PROJECT` may be used to build and push an individual image. `make setup-ecr` can be used to automatically setup ECR repositories for testing.

### `make all-trivy`

`make all-trivy` will use the [Trivy vulnerability scanner](https://github.com/aquasecurity/trivy) to scan for vulnerabilities in the built image and binaries.

`make trivy/PROJECT` will scan only a single project's image.

### `make e2e/TEST`

`make e2e/TEST` will run E2E tests using the [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/). The `TEST` to run is equivalent to the target passed to `make` in the EBS CSI Driver repo (e.g. `make e2e/test-e2e-external`).

### `make licenses/PROJECT`

`make licenses/PROJECT` will output all the licences used by the Golang projects built for these images.

## Contributing and Security

See [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

## License

The build tooling in this repository is licensed under the [Apache License 2.0](./LICENSE). Sub-projects and dependencies have their own licenses, see above section on `make licenses/PROJECT`.
