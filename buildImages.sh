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
    called \"multi-arch-image\", so AMD64 and ARM64 will be available within
    the same tag.

    Usage:
    ${0} [options]
    Optional parameters:
    -a  Also build ARM images beside AMD64
    -b <version>
       .. Version of builder image to use
    -i <version>
       .. Version to tag the image with
    -p  Push image to DockerHub
    -h  Show this help
    "
}

PUSH_IMAGE=''
BUILDER_VERSION='latest'
BUILD_ARM_IMAGES=false
PLATFORM='linux/amd64'
IMAGE_VERSION='latest'

while getopts ab:i:ph? option; do
    case ${option} in
        a) BUILD_ARM_IMAGES=true;;
        b) BUILDER_VERSION="${OPTARG}";;
        i) IMAGE_VERSION="${OPTARG}";;
        p) PUSH_IMAGE=--push;;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

if ${BUILD_ARM_IMAGES} ; then
    PLATFORM=${PLATFORM},linux/arm64
    info "Building AMD64 and ARM64"
else
    info "Building AMD64 only"
fi

info "Building Edomi image"
docker buildx \
    build \
    --platform=${PLATFORM} \
    "--tag=starwarsfan/edomi-docker:${IMAGE_VERSION}" \
    --build-arg "BUILDER_VERSION=${BUILDER_VERSION}" \
    ${PUSH_IMAGE} \
    .
info " -> Done"

# docker buildx imagetools create -t starwarsfan/edomi-docker:${IMAGE_VERSION} starwarsfan/edomi-docker:latest-buildx
