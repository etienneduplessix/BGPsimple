#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

containers=("host_ffarkas-1" "host_ffarkas-2" "router_ffarkas-1" "router_ffarkas-2")
routers=("router_ffarkas-1" "router_ffarkas-2")

# --> INFO
display_info() {
    if ! pgrep -f "docker" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} Docker is not running\n"
        exit 1
    elif ! pgrep -f "gns3" > /dev/null; then
        echo -e "\n${RED}[ERROR]${NC} GNS3 is not running\n"
        exit 1
    fi

    echo -e "\n${BLUE}[host_ffarkas-1]${NC}"
    docker exec "${containers[0]}" sh -c "ifconfig eth1"
    docker exec "${containers[0]}" sh -c "bridge fdb show dev br0"

    echo -e "\n${BLUE}[host_ffarkas-2]${NC}"
    docker exec "${containers[1]}" sh -c "ifconfig eth1"
    docker exec "${containers[1]}" sh -c "bridge fdb show dev br0"

    echo -e "\n${BLUE}[router_ffarkas-1]${NC}"
    docker exec "${containers[2]}" sh -c "ip -d link show vxlan10"

    echo -e "\n${BLUE}[router_ffarkas-2]${NC}"
    docker exec "${containers[3]}" sh -c "ip -d link show vxlan10"

    echo ""
}

# --> DYNAMIC RECONFIG
reconfigure_static_setup() {
    local IP_range=$1

    for router_container in "${routers[@]}"; do
        echo -e "\n${YELLOW}[ROUTER_RECONFIG]${NC} reconfiguring $router_container..."
        set -x
        docker exec "$router_container" sh -c "ip link delete vxlan10"
        docker exec "$router_container" sh -c "ip link delete br0"

        docker exec "$router_container" sh -c "ip link add vxlan10 type vxlan id 10 dstport 4789 dev eth0 group $IP_range"
        docker exec "$router_container" sh -c "ip link set dev vxlan10 up"

        docker exec "$router_container" sh -c "ip link add br0 type bridge"
        docker exec "$router_container" sh -c "ip link set dev br0 up"

        docker exec "$router_container" sh -c "ip link set eth1 master br0"
        docker exec "$router_container" sh -c "ip link set vxlan10 master br0"
        set +x
    done
}

# --> STATIC CONFIG
configure_host() {
    local host_container=$1
    local ip=$2
    echo -e "\n${YELLOW}[HOST_CONFIG]${NC} configuring $host_container..."
    set -x
    docker exec "$host_container" sh -c "ip addr add $ip dev eth1"
    set +x
}

configure_router() {
    local router_container=$1
    local router_ip=$2
    local host_local=$3
    local host_remote=$4
    local bridge_ip=$5

    echo -e "\n${YELLOW}[ROUTER_CONFIG]${NC} configuring $router_container..."
    set -x
    docker exec "$router_container" sh -c "ip addr add $router_ip dev eth0"
    docker exec "$router_container" sh -c "ip link add vxlan10 type vxlan id 10 dstport 4789 dev eth0 local $host_local remote $host_remote"
    docker exec "$router_container" sh -c "ip addr add $bridge_ip dev vxlan10"
    docker exec "$router_container" sh -c "ip link set dev vxlan10 up"

    docker exec "$router_container" sh -c "ip link add br0 type bridge"
    docker exec "$router_container" sh -c "ip link set dev br0 up"

    docker exec "$router_container" sh -c "ip link set eth1 master br0"
    docker exec "$router_container" sh -c "ip link set vxlan10 master br0"
    set +x
}

static_config() {
    configure_host "${containers[0]}" "30.1.1.1/24"
    configure_host "${containers[1]}" "30.1.1.2/24"
    configure_router "${containers[2]}" "10.1.1.1/24" "10.1.1.1" "10.1.1.2" "10.1.1.5/24"
    configure_router "${containers[3]}" "10.1.1.2/24" "10.1.1.2" "10.1.1.1" "10.1.1.6/24"
}

# --> USAGE AND ROUTINE
usage() {
    echo -e "\n${YELLOW}[USAGE]${NC} ./p2_auto.sh [static|dynamic|info]\n"
}

if [ $# -eq 0 ]; then
    usage
    exit 0
elif [ $# -ge 2 ]; then
    echo -e "\n${RED}[ERROR]${NC} bad arguments"
    usage
    exit 1
fi

if [ "$1" = "static" ]; then
    echo -e "\n${RED}--> starting static multicast configuration${NC}"
    static_config
    echo -e "\n${GREEN}[S-CONFIG]${NC} static configuration completed\n"
elif [ "$1" = "dynamic" ]; then
    echo -e "\n${RED}--> starting dynamic multicast reconfiguration${NC}"
    reconfigure_static_setup "239.1.1.1"
    echo -e "\n${GREEN}[D-CONFIG]${NC} dynamic reconfiguration completed\n"
elif [ "$1" = "info" ]; then
    echo -e "\n${RED}--> displaying network configuration${NC}"
    display_info
else
    echo -e "\n${RED}[ERROR]${NC} bad option '$1'"
    usage
    exit 1
fi
