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
    Helper script to build Edomi Docker image.

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
    info "Building starwarsfan/edomi-docker:latest-${_arch}"
    docker build -f "${_arch}.Dockerfile" -t "starwarsfan/edomi-docker:latest-${_arch}" .
    info " -> Done"
    if ${PUBLISH_IMAGE} ; then
        info "Pushing starwarsfan/edomi-docker:latest-${_arch}"
        docker push "starwarsfan/edomi-docker:latest-${_arch}"
        info " -> Done"
    fi
}

PUBLISH_IMAGE=false
BUILD_ARM_IMAGES=false

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
fi
