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

helpMe() {
    echo "
    Helper script to build Edomi Docker image.

    Usage:
    ${0} [options]
    Optional parameters:
    -p  Publish image on DockerHub
    -h  Show this help
    "
}

PUBLISH_IMAGE=false

while getopts ph? option; do
    case ${option} in
        p) PUBLISH_IMAGE=true;;
        h|?) helpMe && exit 0;;
        *) die 90 "invalid option \"${OPTARG}\"";;
    esac
done

docker build -f amd64.Dockerfile -t starwarsfan/edomi-docker:amd64-latest .
if ${PUBLISH_IMAGE} ; then
    docker push starwarsfan/edomi-docker:amd64-latest
fi

docker build -f arm32v7.Dockerfile -t starwarsfan/edomi-docker:arm32v7-latest .
if ${PUBLISH_IMAGE} ; then
    echo "Unsupported at the moment :-/"
#    docker push starwarsfan/edomi-docker:arm32v7-latest
fi
