#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

containers=("host_ffarkas-1" "host_ffarkas-2" "router_ffarkas-1" "router_ffarkas-2")

configure_host() {
    local host_container=$1
    local ip=$2
    echo -e "\n${YELLOW}[HOST_CONFIG]${NC} configuring $host_container..."
    docker exec "$host_container" sh -c "ip addr add $ip dev eth1"
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

display_info() {
    echo -e "\n${BLUE}[host_ffarkas-1]${NC}"
    docker exec "${containers[0]}" sh -c "ifconfig eth1"

    echo -e "\n${BLUE}[host_ffarkas-2]${NC}"
    docker exec "${containers[1]}" sh -c "ifconfig eth1"

    echo -e "\n${BLUE}[router_ffarkas-1]${NC}"
    docker exec "${containers[2]}" sh -c "ip -d link show vxlan10"

    echo -e "\n${BLUE}[router_ffarkas-2]${NC}"
    docker exec "${containers[3]}" sh -c "ip -d link show vxlan10"

    echo ""
}

configure_host "${containers[0]}" "30.1.1.1/24"
configure_host "${containers[1]}" "30.1.1.2/24"
configure_router "${containers[2]}" "10.1.1.1/24" "10.1.1.1" "10.1.1.2" "10.1.1.5/24"
configure_router "${containers[3]}" "10.1.1.2/24" "10.1.1.2" "10.1.1.1" "10.1.1.6/24"

echo -e "\n${GREEN}[CONFIG]${NC} static configuration completed"
display_info
