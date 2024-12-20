#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

hostnames=("host_ffarkas-1" "host_ffarkas-2" "router_ffarkas-1" "router_ffarkas-2")
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

# --> INFO
display_info() {
    check_services
    fetch_containers

    echo -e "\n${BLUE}[${hostnames[0]}]${NC}"
    docker exec "${containers[0]}" sh -c "ifconfig eth1"

    echo -e "\n${BLUE}[${hostnames[1]}]${NC}"
    docker exec "${containers[1]}" sh -c "ifconfig eth1"

    echo -e "\n${BLUE}[${hostnames[2]}]${NC}"
    docker exec "${containers[2]}" sh -c "ip -d link show vxlan10"
    docker exec "${containers[2]}" sh -c "brctl showmacs br0"

    echo -e "\n${BLUE}[${hostnames[3]}]${NC}"
    docker exec "${containers[3]}" sh -c "ip -d link show vxlan10"
    docker exec "${containers[3]}" sh -c "brctl showmacs br0"

    echo ""
}

# --> DYNAMIC RECONFIG
reconfigure_static_setup() {
    check_services
    fetch_containers
    local IP_range=$1
    local routers=("${containers[2]}" "${containers[3]}")
    local vxlan_ips=("$2" "$3")

    for i in "${!routers[@]}"; do
        local router_container="${routers[$i]}"

        echo -e "\n${YELLOW}[ROUTER_RECONFIG]${NC} reconfiguring $router_container..."
        set -x

        docker exec "$router_container" sh -c "ip link delete vxlan10"
        docker exec "$router_container" sh -c "ip link delete br0"

        docker exec "$router_container" sh -c "ip link add vxlan10 type vxlan id 10 dstport 4789 dev eth0 group $IP_range"
        docker exec "$router_container" sh -c "ip addr add ${vxlan_ips[$i]} dev vxlan10"
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
    local device=$3
    echo -e "\n${YELLOW}[HOST_CONFIG]${NC} configuring $device..."
    set -x
    docker exec "$host_container" sh -c "ip addr add $ip dev eth1"
    set +x
}

configure_router() {
    local router_container=$1
    local router_ip=$2
    local host_local=$3
    local host_remote=$4
    local vxlan_ip=$5
    local device=$6

    check_services
    echo -e "\n${YELLOW}[ROUTER_CONFIG]${NC} configuring $device..."
    set -x
    docker exec "$router_container" sh -c "ip addr add $router_ip dev eth0"
    docker exec "$router_container" sh -c "ip link add vxlan10 type vxlan id 10 dstport 4789 dev eth0 local $host_local remote $host_remote"
    docker exec "$router_container" sh -c "ip addr add $vxlan_ip dev vxlan10"
    docker exec "$router_container" sh -c "ip link set dev vxlan10 up"

    docker exec "$router_container" sh -c "ip link add br0 type bridge"
    docker exec "$router_container" sh -c "ip link set dev br0 up"

    docker exec "$router_container" sh -c "ip link set eth1 master br0"
    docker exec "$router_container" sh -c "ip link set vxlan10 master br0"
    set +x
}

static_config() {
    check_services
    fetch_containers
    configure_host "${containers[0]}" "30.1.1.1/24" "${hostnames[0]}"
    configure_host "${containers[1]}" "30.1.1.2/24" "${hostnames[1]}"
    configure_router "${containers[2]}" "10.1.1.1/24" "10.1.1.1" "10.1.1.2" "20.1.1.1/24" "${hostnames[2]}"
    configure_router "${containers[3]}" "10.1.1.2/24" "10.1.1.2" "10.1.1.1" "20.1.1.2/24" "${hostnames[3]}"
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
    reconfigure_static_setup "239.1.1.1" "20.1.1.1/24" "20.1.1.2/24"
    echo -e "\n${GREEN}[D-CONFIG]${NC} dynamic reconfiguration completed\n"
elif [ "$1" = "info" ]; then
    echo -e "\n${RED}--> displaying network configuration${NC}"
    display_info
else
    echo -e "\n${RED}[ERROR]${NC} bad option '$1'"
    usage
    exit 1
fi
