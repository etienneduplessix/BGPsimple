#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

hostnames=("_ffarkas-1" "_ffarkas-2" "_ffarkas-3" "_ffarkas-4" "host_ffarkas-1" "host_ffarkas-2" "host_ffarkas-3")
containers=()

# --> CHECK SERVICES
check_services() {
    if ! pgrep -f "docker" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} Docker is not running\n"
        exit 1
    elif ! pgrep -f "gns3" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} GNS3 is not running\n"
        exit 1
    fi
}

# --> ASSIGN CONTAINERS
fetch_containers() {
    echo -e "\n${YELLOW}[MATCHING]${NC} matching containers to hostnames..."

    for device_hostname in "${hostnames[@]}"; do
        for container_id in $(docker ps -q); do
            hostname=$(docker inspect --format '{{.Config.Hostname}}' "$container_id")
            if [[ "$hostname" == "$device_hostname" ]]; then
                container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's|^/||')
                echo "${hostname}: ${container_name}"
                containers+=("$container_name")
            fi
        done
    done
}

# --> CONFIG
configure_hosts() {
    check_services
    fetch_containers
    echo -e "\n${RED}--> starting hosts' configuration${NC}"

    for h_id in {1..3}; do
        echo -e "\n${BLUE}[ROUTER_CONFIG]${NC} configuring _ffarkas-${h_id}_host\n"
        cat "_ffarkas-${h_id}_host"
        docker exec -i "${containers[${h_id}+3]}" /bin/sh < "_ffarkas-${h_id}_host" > /dev/null 2>&1
    done

    echo -e "\n${GREEN}[HOST_CONFIG]${NC} all hosts' configurations completed\n"
}

configure_routers() {
    check_services
    fetch_containers
    echo -e "\n${RED}--> starting routers' configuration${NC}"

    for r_id in {4..1}; do
        echo -e "\n${BLUE}[ROUTER_CONFIG]${NC} configuring _ffarkas-${r_id}\n"
        cat "_ffarkas-${r_id}"
        docker exec -i "${containers[r_id-1]}" /bin/sh < "_ffarkas-${r_id}" > /dev/null 2>&1
    done

    echo -e "\n${GREEN}[ROUTER_CONFIG]${NC} all routers' configurations completed\n"
}

# --> USAGE AND ROUTINE
usage() {
    echo -e "\n${YELLOW}[USAGE]${NC} ./p3_auto.sh [r_config|h_config]\n"
}

error() {
    echo -e "\n${RED}[ERROR]${NC} bad arguments"
    usage
    exit 1
}

[ $# -eq 0 ] && usage && exit 0
[ $# -ne 1 ] && error

if [ "$1" = "r_config" ]; then
    configure_routers
elif [ "$1" = "h_config" ]; then
    configure_hosts
else
    echo -e "\n${RED}[ERROR]${NC} bad option '$1'"
    usage
    exit 1
fi
