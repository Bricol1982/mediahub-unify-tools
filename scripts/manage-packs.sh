#!/bin/bash
# MediaHub Pack Manager
# Switch between installation packs (minimal, essential, full)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
PACKS_CONFIG="$PROJECT_DIR/config/packs.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load pack definitions
if [[ -f "$PACKS_CONFIG" ]]; then
    source "$PACKS_CONFIG"
elif [[ -f "$INSTALL_DIR/config/packs.conf" ]]; then
    source "$INSTALL_DIR/config/packs.conf"
else
    echo -e "${RED}Error: packs.conf not found${NC}"
    exit 1
fi

show_help() {
    echo -e "${CYAN}MediaHub Pack Manager${NC}"
    echo ""
    echo "Usage: $0 [command] [pack]"
    echo ""
    echo "Commands:"
    echo "  status              Show current pack and running services"
    echo "  list                List available packs"
    echo "  info <pack>         Show detailed info about a pack"
    echo "  switch <pack>       Switch to a different pack"
    echo "  add <service>       Add a single service to current pack"
    echo "  remove <service>    Remove a single service from current pack"
    echo "  custom              Interactive custom pack builder"
    echo ""
    echo "Packs:"
    echo "  minimal             Basic media streaming (7 services)"
    echo "  essential           Core features with management (15 services)"
    echo "  full                All available features (30+ services)"
    echo ""
}

get_current_pack() {
    if [[ -f "$INSTALL_DIR/.current_pack" ]]; then
        cat "$INSTALL_DIR/.current_pack"
    else
        echo "unknown"
    fi
}

get_running_services() {
    docker compose -f "$INSTALL_DIR/docker-compose.yml" ps --services 2>/dev/null | sort
}

count_services() {
    local pack="$1"
    case "$pack" in
        minimal) echo "$PACK_MINIMAL" | wc -w ;;
        essential) echo "$PACK_ESSENTIAL" | wc -w ;;
        full) echo "$PACK_FULL" | wc -w ;;
        *) echo 0 ;;
    esac
}

show_status() {
    local current_pack=$(get_current_pack)
    local running=$(docker compose -f "$INSTALL_DIR/docker-compose.yml" ps --services 2>/dev/null | wc -l)
    local total_containers=$(docker ps -q 2>/dev/null | wc -l)

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}       MediaHub Pack Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "Current Pack: ${GREEN}$current_pack${NC}"
    echo -e "Running Services: ${YELLOW}$running${NC}"
    echo -e "Total Containers: ${YELLOW}$total_containers${NC}"
    echo ""

    # Show RAM and disk usage
    local mem_used=$(free -m | awk '/^Mem:/{print $3}')
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    local disk_used=$(df -h /mnt/media 2>/dev/null | awk 'NR==2{print $3}' || echo "N/A")
    local disk_total=$(df -h /mnt/media 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")

    echo -e "Memory: ${mem_used}MB / ${mem_total}MB"
    echo -e "Disk (Media): ${disk_used} / ${disk_total}"
    echo ""

    echo -e "${BLUE}Running Services:${NC}"
    get_running_services | while read service; do
        local status=$(docker inspect --format='{{.State.Status}}' "$service" 2>/dev/null || echo "unknown")
        if [[ "$status" == "running" ]]; then
            echo -e "  ${GREEN}●${NC} $service"
        else
            echo -e "  ${RED}○${NC} $service ($status)"
        fi
    done
}

list_packs() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}       Available Installation Packs${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    local current=$(get_current_pack)

    # Minimal
    local min_count=$(count_services minimal)
    if [[ "$current" == "minimal" ]]; then
        echo -e "${GREEN}► MINIMAL${NC} (Current)"
    else
        echo -e "${YELLOW}  MINIMAL${NC}"
    fi
    echo "    Services: $min_count"
    echo "    RAM: ~${RAM_MINIMAL}MB"
    echo "    Disk: ~${DISK_MINIMAL}GB"
    echo "    Best for: Low-resource systems, basic streaming"
    echo ""

    # Essential
    local ess_count=$(count_services essential)
    if [[ "$current" == "essential" ]]; then
        echo -e "${GREEN}► ESSENTIAL${NC} (Current)"
    else
        echo -e "${YELLOW}  ESSENTIAL${NC}"
    fi
    echo "    Services: $ess_count"
    echo "    RAM: ~${RAM_ESSENTIAL}MB"
    echo "    Disk: ~${DISK_ESSENTIAL}GB"
    echo "    Best for: Standard home media server"
    echo ""

    # Full
    local full_count=$(count_services full)
    if [[ "$current" == "full" ]]; then
        echo -e "${GREEN}► FULL${NC} (Current)"
    else
        echo -e "${YELLOW}  FULL${NC}"
    fi
    echo "    Services: $full_count"
    echo "    RAM: ~${RAM_FULL}MB"
    echo "    Disk: ~${DISK_FULL}GB"
    echo "    Best for: Full-featured media hub"
    echo ""
}

show_pack_info() {
    local pack="$1"
    local services=""

    case "$pack" in
        minimal) services="$PACK_MINIMAL" ;;
        essential) services="$PACK_ESSENTIAL" ;;
        full) services="$PACK_FULL" ;;
        *)
            echo -e "${RED}Unknown pack: $pack${NC}"
            exit 1
            ;;
    esac

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}       Pack: $(echo $pack | tr '[:lower:]' '[:upper:]')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${BLUE}Included Services:${NC}"
    for service in $services; do
        local desc_var="DESC_${service//-/_}"
        local desc="${!desc_var:-$service}"
        echo -e "  • $service - $desc"
    done
    echo ""
}

generate_compose_override() {
    local pack="$1"
    local services=""

    case "$pack" in
        minimal) services="$PACK_MINIMAL" ;;
        essential) services="$PACK_ESSENTIAL" ;;
        full) services="$PACK_FULL" ;;
        custom) services="$2" ;;
        *)
            echo -e "${RED}Unknown pack: $pack${NC}"
            return 1
            ;;
    esac

    # Create docker-compose.override.yml to disable services not in pack
    local override_file="$INSTALL_DIR/docker-compose.override.yml"

    echo "# Auto-generated by pack manager" > "$override_file"
    echo "# Pack: $pack" >> "$override_file"
    echo "# Generated: $(date)" >> "$override_file"
    echo "" >> "$override_file"
    echo "version: '3.8'" >> "$override_file"
    echo "" >> "$override_file"
    echo "services:" >> "$override_file"

    # Get all services from main compose file
    local all_services=$(docker compose -f "$INSTALL_DIR/docker-compose.yml" config --services 2>/dev/null)

    for svc in $all_services; do
        if ! echo "$services" | grep -qw "$svc"; then
            # Service not in pack - disable it by setting replicas to 0
            echo "  $svc:" >> "$override_file"
            echo "    deploy:" >> "$override_file"
            echo "      replicas: 0" >> "$override_file"
        fi
    done

    echo -e "${GREEN}Generated override file for $pack pack${NC}"
}

switch_pack() {
    local new_pack="$1"
    local current_pack=$(get_current_pack)

    if [[ "$new_pack" == "$current_pack" ]]; then
        echo -e "${YELLOW}Already using $new_pack pack${NC}"
        return 0
    fi

    echo -e "${CYAN}Switching from $current_pack to $new_pack pack...${NC}"
    echo ""

    # Show what will change
    show_pack_info "$new_pack"

    read -p "Continue with pack switch? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return 0
    fi

    # Stop current services
    echo -e "${BLUE}Stopping current services...${NC}"
    cd "$INSTALL_DIR"
    docker compose down 2>/dev/null || true

    # Generate new override
    echo -e "${BLUE}Configuring $new_pack pack...${NC}"
    generate_compose_override "$new_pack"

    # Start new pack
    echo -e "${BLUE}Starting $new_pack pack services...${NC}"
    docker compose up -d

    # Save current pack
    echo "$new_pack" > "$INSTALL_DIR/.current_pack"

    echo ""
    echo -e "${GREEN}Successfully switched to $new_pack pack!${NC}"
    echo ""

    # Show new status
    sleep 3
    show_status
}

add_service() {
    local service="$1"
    local current_pack=$(get_current_pack)

    echo -e "${BLUE}Adding service: $service${NC}"

    cd "$INSTALL_DIR"
    docker compose up -d "$service"

    echo -e "${GREEN}Service $service added${NC}"
}

remove_service() {
    local service="$1"

    echo -e "${YELLOW}Removing service: $service${NC}"

    cd "$INSTALL_DIR"
    docker compose stop "$service" 2>/dev/null || true
    docker compose rm -f "$service" 2>/dev/null || true

    echo -e "${GREEN}Service $service removed${NC}"
}

interactive_custom() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}       Custom Pack Builder${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    local selected_services="gluetun qbittorrent"  # Always required

    echo -e "${YELLOW}Core services (always included):${NC}"
    echo "  • gluetun - VPN Tunnel"
    echo "  • qbittorrent - Torrent Client"
    echo ""

    # Media Managers
    echo -e "${BLUE}Media Managers:${NC}"
    read -p "  Include Sonarr (TV Shows)? (Y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && selected_services+=" prowlarr flaresolverr sonarr"

    read -p "  Include Radarr (Movies)? (Y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && selected_services+=" radarr"

    read -p "  Include Lidarr (Music)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" lidarr"

    read -p "  Include Bazarr (Subtitles)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" bazarr"

    # Media Servers
    echo -e "${BLUE}Media Servers:${NC}"
    read -p "  Include Jellyfin (Media Server)? (Y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && selected_services+=" jellyfin"

    read -p "  Include Navidrome (Music Streaming)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" navidrome"

    read -p "  Include Komga (Comics/Manga)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" komga"

    read -p "  Include PhotoPrism (Photo Gallery)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" photoprism"

    # Management
    echo -e "${BLUE}Management:${NC}"
    read -p "  Include Jellyseerr (Requests)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" jellyseerr"

    read -p "  Include Homarr (Dashboard)? (Y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && selected_services+=" homarr"

    read -p "  Include Portainer (Docker UI)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" portainer"

    # Monitoring
    echo -e "${BLUE}Monitoring:${NC}"
    read -p "  Include Uptime Kuma (Service Monitor)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" uptime-kuma"

    read -p "  Include Netdata (System Monitor)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" netdata"

    # Extras
    echo -e "${BLUE}Extras:${NC}"
    read -p "  Include Watchtower (Auto Updates)? (Y/n) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && selected_services+=" watchtower"

    read -p "  Include Pi-hole (Ad Blocker)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" pihole"

    read -p "  Include Duplicati (Backups)? (y/N) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && selected_services+=" duplicati"

    echo ""
    echo -e "${GREEN}Selected services:${NC}"
    echo "$selected_services" | tr ' ' '\n' | sort | uniq | while read svc; do
        echo "  • $svc"
    done

    local service_count=$(echo "$selected_services" | tr ' ' '\n' | sort | uniq | wc -l)
    echo ""
    echo -e "Total: ${YELLOW}$service_count services${NC}"
    echo ""

    read -p "Apply this custom configuration? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$INSTALL_DIR"
        docker compose down 2>/dev/null || true
        generate_compose_override "custom" "$selected_services"
        docker compose up -d
        echo "custom" > "$INSTALL_DIR/.current_pack"
        echo -e "${GREEN}Custom pack applied!${NC}"
    fi
}

# API mode for dashboard integration
api_mode() {
    local action="$1"
    local param="$2"

    case "$action" in
        "status")
            echo "pack=$(get_current_pack)"
            echo "services=$(get_running_services | wc -l)"
            ;;
        "list")
            echo "minimal essential full"
            ;;
        "switch")
            switch_pack "$param" > /dev/null 2>&1
            echo "ok"
            ;;
        *)
            echo "error"
            ;;
    esac
}

# Main
case "${1:-help}" in
    status) show_status ;;
    list) list_packs ;;
    info) show_pack_info "${2:-minimal}" ;;
    switch) switch_pack "${2:-essential}" ;;
    add) add_service "$2" ;;
    remove) remove_service "$2" ;;
    custom) interactive_custom ;;
    api) api_mode "$2" "$3" ;;
    *) show_help ;;
esac
