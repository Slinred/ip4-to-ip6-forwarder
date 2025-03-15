#!/bin/bash
VERSION=$(cat VERSION | tr -d '\n')

VERSIONS="$VERSION latest"

for BUILD_VERSION in $VERSIONS; do
    echo "Building version: $BUILD_VERSION"
    docker buildx build --no-cache -f ./docker/Dockerfile -t slinred/ip4-to-ip6-forwarder:${BUILD_VERSION} --platform linux/arm64,linux/amd64 $* .
    if [ $? -ne 0 ]; then
        echo "Failed to build image!"
        exit 1
    fi
done

docker image ls