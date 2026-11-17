# syntax=docker.io/docker/dockerfile:1.25.0

ARG BASE_IMAGE=docker.io/rockylinux/rockylinux:10.2.20260525.0
ARG GOLANG_IMAGE=docker.io/library/golang:1.26

FROM --platform=${BUILDPLATFORM} ${GOLANG_IMAGE} AS base

ARG GITHUB_URL=https://github.com
# ARG GITHUB_URL=https://gh-proxy.org/https://github.com
# ARG GITHUB_URL=https://nexus-mirror.alpha-quant.tech/repository/github

# skopeo
# https://github.com/containers/skopeo/releases
ARG INST_SKOPEO_V=v1.25.2

ARG VENDOR_ARCHES="amd64 arm64"

# Upstream static build recipe, see install.md "Building a static binary"
# and the DISABLE_CGO branch of the upstream Makefile.
ARG SKOPEO_BUILDTAGS="exclude_graphdriver_btrfs containers_image_openpgp"

ENV \
    GITHUB_URL=${GITHUB_URL} \
    INST_SKOPEO_V=${INST_SKOPEO_V} \
    VENDOR_ARCHES=${VENDOR_ARCHES} \
    SKOPEO_BUILDTAGS=${SKOPEO_BUILDTAGS} \
    CGO_ENABLED=0 \
    GOFLAGS=-mod=vendor \
    GOTOOLCHAIN=local

# ---------------------------------------------------------------------------
# binaries
#    /cpaas/vendor/skopeo/<arch>/skopeo
#    /cpaas/vendor/skopeo/<arch>/skopeo.sha256sum
#    /cpaas/vendor/skopeo/<arch>/policy.json
#
# ---------------------------------------------------------------------------
FROM --platform=${BUILDPLATFORM} base AS binaries

WORKDIR /src

RUN --mount=type=cache,target=/tmp,id=build-tmp,sharing=locked \
    set -eu \
    && tarball="/tmp/skopeo-${INST_SKOPEO_V}.tar.gz" \
    && curl --fail -sL -m 300 --retry 3 --retry-delay 5 \
    "${GITHUB_URL}/containers/skopeo/archive/refs/tags/${INST_SKOPEO_V}.tar.gz" -o "${tarball}" \
    && tar -xzf "${tarball}" --strip-components 1 -C /src \
    && src_v="$(sed -n 's/^const Version = "\(.*\)"$/\1/p' version/version.go)" \
    && test "v${src_v}" = "${INST_SKOPEO_V}" \
    || { echo "source version mismatch: version.go=${src_v}, want ${INST_SKOPEO_V}" >&2; exit 1; }

RUN --mount=type=cache,target=/root/.cache/go-build,id=skopeo-go-build \
    set -eu \
    && for arch in ${VENDOR_ARCHES}; do \
    dst="/cpaas/vendor/skopeo/${arch}" ; \
    mkdir -p "${dst}" ; \
    GOOS=linux GOARCH="${arch}" go build -trimpath \
    -tags "${SKOPEO_BUILDTAGS}" -o "${dst}/skopeo" ./cmd/skopeo ; \
    cp default-policy.json "${dst}/policy.json" ; \
    ( cd "${dst}" && sha256sum skopeo > skopeo.sha256sum ) ; \
    done

RUN set -eu \
    && host_arch="$(go env GOHOSTARCH)" \
    && for arch in ${VENDOR_ARCHES}; do \
    dst="/cpaas/vendor/skopeo/${arch}" ; \
    test -x "${dst}/skopeo" \
    || { echo "missing binary: ${arch}/skopeo" >&2; exit 1; } ; \
    test -s "${dst}/policy.json" \
    || { echo "missing policy: ${arch}/policy.json" >&2; exit 1; } ; \
    magic="$(od -An -tx1 -N4 "${dst}/skopeo" | tr -d ' \n')" ; \
    test "${magic}" = "7f454c46" \
    || { echo "not an ELF binary: ${arch}/skopeo (magic=${magic})" >&2; exit 1; } ; \
    case "${arch}" in \
    amd64) want="3e00" ;; \
    arm64) want="b700" ;; \
    ppc64le) want="1500" ;; \
    riscv64) want="f300" ;; \
    s390x) want="0016" ;; \
    *) want="" ;; \
    esac ; \
    machine="$(od -An -tx1 -j18 -N2 "${dst}/skopeo" | tr -d ' \n')" ; \
    { test -z "${want}" || test "${machine}" = "${want}" ; } \
    || { echo "ELF arch mismatch: ${arch}/skopeo (e_machine=${machine}, want=${want})" >&2; exit 1; } ; \
    go version -m "${dst}/skopeo" | grep -q 'CGO_ENABLED=0' \
    || { echo "not a static build: ${arch}/skopeo" >&2; exit 1; } ; \
    if [ "${arch}" = "${host_arch}" ]; then \
    "${dst}/skopeo" --version | grep -qx "skopeo version ${INST_SKOPEO_V#v}" \
    || { echo "unexpected version: $("${dst}/skopeo" --version)" >&2; exit 1; } ; \
    fi ; \
    ( cd "${dst}" && sha256sum --check --strict ./*.sha256sum ) ; \
    done

# ---------------------------------------------------------------------------
# target
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG TARGETARCH

# skopeo
# https://github.com/containers/skopeo/releases
ARG INST_SKOPEO_V=v1.25.2

ENV INST_SKOPEO_V=${INST_SKOPEO_V}

COPY --from=binaries /cpaas/vendor/skopeo/${TARGETARCH}/ /cpaas/vendor/skopeo/

LABEL \
    org.opencontainers.image.title="kluster-vendor-skopeo" \
    org.opencontainers.image.description="Upstream skopeo built as static binaries and packaged as OCI artifacts" \
    org.opencontainers.image.version="${INST_SKOPEO_V}" \
    org.opencontainers.image.source="https://github.com/cpaas-dev/kluster-vendor-skopeo" \
    org.opencontainers.image.vendor="Kluster" \
    org.opencontainers.image.licenses="Apache-2.0"
