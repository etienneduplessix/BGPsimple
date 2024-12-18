#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

routers=("router_ffarkas-1" "router_ffarkas-2")
containers=("host_ffarkas-1" "host_ffarkas-2" "router_ffarkas-1" "router_ffarkas-2")

replace_static_setup() {
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

display_info() {
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

replace_static_setup "239.1.1.1"

echo -e "\n${GREEN}[ROUTER_RECONFIG]${NC} dynamic reconfiguration completed"
display_info
