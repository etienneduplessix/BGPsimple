#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

build_images() {
    if ! pgrep -f "docker" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} Docker is not running\n"
        exit 1
    fi

    echo -e "\n${GREEN}[BUILD]${NC} building images...\n"
    docker buildx build --tag host_ffarkas --file host_ffarkas.Dockerfile --load .
    docker buildx build --tag router_ffarkas --file router_ffarkas.Dockerfile --load .
}

container_info() {
    if ! pgrep -f "docker" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} Docker is not running\n"
        exit 1
    elif ! pgrep -f "gns3" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} GNS3 is not running\n"
        exit 1
    fi

    echo -e "\n${YELLOW}[INFO]${NC} displaying containers info..."

    for container in $(docker container ls -q); do
        HOSTNAME=$(docker exec "$container" hostname)
        echo -e "\n${GREEN}$HOSTNAME${NC} (ID $container)"
        docker exec "$container" ps aux
    done
    echo ""
}

usage() {
    echo -e "\n${YELLOW}[USAGE]${NC} ./p1_auto.sh [build|info]\n"
}

if [ $# -eq 0 ]; then
    usage
    exit 0
elif [ $# -ge 2 ]; then
    echo -e "\n${RED}[ERROR]${NC} bad arguments"
    usage
    exit 1
fi

if [ "$1" = "build" ]; then
    build_images
elif [ "$1" = "info" ]; then
    container_info
else
    echo -e "\n${RED}[ERROR]${NC} bad option '$1'"
    usage
    exit 1
fi
