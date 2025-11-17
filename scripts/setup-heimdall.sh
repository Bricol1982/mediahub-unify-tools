#!/bin/bash
# Setup Heimdall dashboard with all Essential pack applications
# This script automatically adds app tiles to Heimdall

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
HEIMDALL_CONFIG="${HEIMDALL_CONFIG:-$INSTALL_DIR/config/heimdall}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get Raspberry Pi IP
RPI_IP="${RPI_IP:-$(hostname -I | awk '{print $1}')}"

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}     Heimdall Dashboard Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "Raspberry Pi IP: ${GREEN}$RPI_IP${NC}"
echo ""

# Wait for Heimdall to be running
echo -e "${BLUE}Checking Heimdall status...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "^heimdall$"; then
    echo -e "${RED}Heimdall container is not running${NC}"
    echo "Start it with: docker compose up -d heimdall"
    exit 1
fi

# Heimdall uses SQLite database
HEIMDALL_DB="$HEIMDALL_CONFIG/www/app.sqlite"

# Wait for database to be created
echo -e "${BLUE}Waiting for Heimdall database...${NC}"
for i in {1..30}; do
    if [[ -f "$HEIMDALL_DB" ]]; then
        echo -e "${GREEN}Database found${NC}"
        break
    fi
    sleep 2
done

if [[ ! -f "$HEIMDALL_DB" ]]; then
    echo -e "${YELLOW}Database not found. Creating via API...${NC}"
fi

# Check if sqlite3 is available on host
if ! command -v sqlite3 &>/dev/null; then
    echo -e "${YELLOW}Installing sqlite3...${NC}"
    apt-get update -qq && apt-get install -y -qq sqlite3
fi

# Function to add app via Heimdall's database (using host sqlite3)
add_app_to_db() {
    local title="$1"
    local url="$2"
    local icon="$3"
    local color="$4"
    local description="$5"
    local order="$6"

    # Check if app already exists
    if sqlite3 "$HEIMDALL_DB" \
        "SELECT COUNT(*) FROM items WHERE title='$title';" 2>/dev/null | grep -q "^[1-9]"; then
        echo -e "  ${YELLOW}⊘${NC} $title (already exists)"
        return
    fi

    # Insert into database with user_id=0 for public visibility (no login required)
    sqlite3 "$HEIMDALL_DB" "
        INSERT INTO items (title, url, colour, icon, description, pinned, type, user_id, created_at, updated_at, \"order\", deleted_at, class)
        VALUES ('$title', '$url', '$color', '$icon', '$description', 1, 0, 0, datetime('now'), datetime('now'), $order, NULL, 'item');
    " 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $title"
    else
        echo -e "  ${RED}✗${NC} $title (failed to add)"
    fi
}

echo -e "${BLUE}Adding Essential Pack applications to Heimdall...${NC}"
echo ""

# Essential Pack Applications
# Format: title, url, icon, color, description, order

# Core Services
add_app_to_db "qBittorrent" "http://$RPI_IP:8080" "" "#2f7eed" "Torrent Client" 1
add_app_to_db "Prowlarr" "http://$RPI_IP:9696" "" "#ffc230" "Indexer Manager" 2
add_app_to_db "FlareSolverr" "http://$RPI_IP:8191" "" "#ff7b00" "Anti-Bot Solver" 3

# Media Managers (*arr Suite)
add_app_to_db "Sonarr" "http://$RPI_IP:8989" "" "#00ccff" "TV Shows Manager" 4
add_app_to_db "Radarr" "http://$RPI_IP:7878" "" "#ffc230" "Movies Manager" 5
add_app_to_db "Lidarr" "http://$RPI_IP:8686" "" "#00cc00" "Music Manager" 6
add_app_to_db "Bazarr" "http://$RPI_IP:6767" "" "#8e44ad" "Subtitles Manager" 7

# Media Server
add_app_to_db "Jellyfin" "http://$RPI_IP:8096" "" "#00a4dc" "Media Server" 8
add_app_to_db "Jellyseerr" "http://$RPI_IP:5055" "" "#4c00b0" "Request Manager" 9

# Management Tools
add_app_to_db "Portainer" "http://$RPI_IP:9000" "" "#13bef9" "Docker Management" 10
add_app_to_db "Watchtower" "http://$RPI_IP:8082" "" "#00d1b2" "Auto Updates" 11

# System Info (no web UI but useful links)
add_app_to_db "Unpackerr" "http://$RPI_IP:5656" "" "#e74c3c" "Archive Extractor" 12

echo ""
echo -e "${GREEN}✓ Heimdall configuration complete!${NC}"
echo ""

# Restart Heimdall to apply changes
echo -e "${BLUE}Restarting Heimdall to apply changes...${NC}"
docker restart heimdall

sleep 3

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Heimdall is ready!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "Access your dashboard at: ${GREEN}http://$RPI_IP:80${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} You can customize icons and colors in the Heimdall web interface."
echo "Click on any app tile to edit its settings."
echo ""

# Show quick reference
echo -e "${BLUE}Quick Reference - Service Ports:${NC}"
echo "  Heimdall (Dashboard):  80"
echo "  qBittorrent:           8080"
echo "  Prowlarr:              9696"
echo "  FlareSolverr:          8191"
echo "  Sonarr:                8989"
echo "  Radarr:                7878"
echo "  Lidarr:                8686"
echo "  Bazarr:                6767"
echo "  Jellyfin:              8096"
echo "  Jellyseerr:            5055"
echo "  Portainer:             9000"
echo ""
