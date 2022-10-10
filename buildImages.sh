#!/usr/bin/env bash
# ===========================================================================
#
# Created: 2020-01-05 Y. Schumann
#
# Helper script to build and push Edomi image
#
# ===========================================================================

# Store path from where script was called, determine own location
# and source helper content from there
callDir=$(pwd)
ownLocation="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${ownLocation}
. ./include/helpers_console.sh
_init

helpMe() {
    echo "
    Helper script to build Edomi Docker image. The build will produce a so
    called \"multi-arch-image\", so x86_64 and ARMv8 will be available within
    the same tag.

    Usage:
    ${0} [options]
    Optional parameters:
    -a  Also build ARM images beside AMD64
    -p  Publish image on DockerHub
    -h  Show this help
    "
}

buildImage() {
    local _arch=$1
    info "Building starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch}"
    docker build -f "${_arch}.Dockerfile" -t "starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch}" .
    info " -> Done"
    if ${PUBLISH_IMAGE} ; then
        info "Pushing starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch}"
        docker push "starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch}"
        info " -> Done"
    fi
}

buildManifest() {
    local _arch1=$1
    local _arch2=$2
    info "Building docker manifest for starwarsfan/edomi-docker${IMAGE_SUFFIX}:${IMAGE_VERSION}"
    if [ -z "${_arch2}" ] ; then
        docker manifest create \
            "starwarsfan/edomi-docker${IMAGE_SUFFIX}:${IMAGE_VERSION}" \
            --amend "starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch1}"
    else
        docker manifest create \
            "starwarsfan/edomi-docker${IMAGE_SUFFIX}:${IMAGE_VERSION}" \
            --amend "starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch1}" \
            --amend "starwarsfan/edomi-docker${IMAGE_SUFFIX}:manifest-${_arch2}"
    fi
    info " -> Done"
    if ${PUBLISH_IMAGE} ; then
        info "Pushing docker manifest starwarsfan/edomi-docker${IMAGE_SUFFIX}:${IMAGE_VERSION}"
        docker manifest push "starwarsfan/edomi-docker${IMAGE_SUFFIX}:${IMAGE_VERSION}"
        info " -> Done"
    fi
}

PUBLISH_IMAGE=false
BUILD_ARM_IMAGES=false
IMAGE_SUFFIX=
IMAGE_VERSION=2.03.5

while getopts aph? option; do
    case ${option} in
        a) BUILD_ARM_IMAGES=true;;
        p) PUBLISH_IMAGE=true;;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

info "Disabling buildkit etc. pp."
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0
info " -> Done"

buildImage amd64
if ${BUILD_ARM_IMAGES} ; then
    buildImage arm64
    buildManifest amd64 arm64
else
    buildManifest amd64
fi
