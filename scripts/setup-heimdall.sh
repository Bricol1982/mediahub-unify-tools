#!/bin/bash
# Setup Heimdall dashboard with all Essential pack applications
# This script generates a pre-configured Heimdall database

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

# Check if Heimdall is running
echo -e "${BLUE}Checking Heimdall status...${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "^heimdall$"; then
    echo -e "${RED}Heimdall container is not running${NC}"
    echo "Start it with: docker compose up -d heimdall"
    exit 1
fi

# Stop Heimdall to modify config
echo -e "${BLUE}Stopping Heimdall temporarily...${NC}"
docker stop heimdall

# Create Heimdall config directory if not exists
mkdir -p "$HEIMDALL_CONFIG/www"

# Remove old database to start fresh
if [[ -f "$HEIMDALL_CONFIG/www/app.sqlite" ]]; then
    echo -e "${YELLOW}Removing old database...${NC}"
    rm -f "$HEIMDALL_CONFIG/www/app.sqlite"
    rm -f "$HEIMDALL_CONFIG/www/app.sqlite-shm"
    rm -f "$HEIMDALL_CONFIG/www/app.sqlite-wal"
fi

# Start Heimdall to create fresh database
echo -e "${BLUE}Starting Heimdall to initialize database...${NC}"
docker start heimdall

# Wait for database to be created
echo -e "${BLUE}Waiting for database initialization...${NC}"
for i in {1..30}; do
    if [[ -f "$HEIMDALL_CONFIG/www/app.sqlite" ]]; then
        echo -e "${GREEN}Database created${NC}"
        break
    fi
    sleep 2
done

if [[ ! -f "$HEIMDALL_CONFIG/www/app.sqlite" ]]; then
    echo -e "${RED}Database not created after 60 seconds${NC}"
    exit 1
fi

# Wait a bit more for Heimdall to fully initialize
sleep 5

# Check if sqlite3 is available on host
if ! command -v sqlite3 &>/dev/null; then
    echo -e "${YELLOW}Installing sqlite3...${NC}"
    apt-get update -qq && apt-get install -y -qq sqlite3
fi

HEIMDALL_DB="$HEIMDALL_CONFIG/www/app.sqlite"

# Create admin user with public_front enabled
echo -e "${BLUE}Configuring admin user...${NC}"
sqlite3 "$HEIMDALL_DB" "
    DELETE FROM users;
    INSERT INTO users (id, username, email, avatar, password, autologin, public_front, remember_token, created_at, updated_at)
    VALUES (1, 'admin', 'admin@mediahub.local', NULL, '', NULL, 1, NULL, datetime('now'), datetime('now'));
"

echo -e "${BLUE}Adding Essential Pack applications...${NC}"
echo ""

# Counter for order
ORDER=0

# Function to add app
add_app() {
    local title="$1"
    local url="$2"
    local color="$3"
    local description="$4"

    ORDER=$((ORDER + 1))

    sqlite3 "$HEIMDALL_DB" "
        INSERT INTO items (title, url, colour, icon, description, pinned, type, user_id, created_at, updated_at, \"order\", deleted_at, class)
        VALUES ('$title', '$url', '$color', '', '$description', 1, 0, 1, datetime('now'), datetime('now'), $ORDER, NULL, NULL);
    "

    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $title"
    else
        echo -e "  ${RED}✗${NC} $title"
    fi
}

# Essential Pack Applications
add_app "qBittorrent" "http://$RPI_IP:8080" "#2f7eed" "Torrent Client"
add_app "Prowlarr" "http://$RPI_IP:9696" "#ffc230" "Indexer Manager"
add_app "FlareSolverr" "http://$RPI_IP:8191" "#ff7b00" "Anti-Bot Solver"
add_app "Sonarr" "http://$RPI_IP:8989" "#00ccff" "TV Shows Manager"
add_app "Radarr" "http://$RPI_IP:7878" "#ffc230" "Movies Manager"
add_app "Lidarr" "http://$RPI_IP:8686" "#00cc00" "Music Manager"
add_app "Bazarr" "http://$RPI_IP:6767" "#8e44ad" "Subtitles Manager"
add_app "Jellyfin" "http://$RPI_IP:8096" "#00a4dc" "Media Server"
add_app "Jellyseerr" "http://$RPI_IP:5055" "#4c00b0" "Request Manager"
add_app "Portainer" "http://$RPI_IP:9000" "#13bef9" "Docker Management"

echo ""

# Verify the data
echo -e "${BLUE}Verifying configuration...${NC}"
ITEM_COUNT=$(sqlite3 "$HEIMDALL_DB" "SELECT COUNT(*) FROM items;")
USER_PUBLIC=$(sqlite3 "$HEIMDALL_DB" "SELECT public_front FROM users WHERE id=1;")

echo -e "  Items created: ${GREEN}$ITEM_COUNT${NC}"
echo -e "  Public dashboard: ${GREEN}$([[ $USER_PUBLIC == 1 ]] && echo "Enabled" || echo "Disabled")${NC}"

# Restart Heimdall to load new config
echo -e "${BLUE}Restarting Heimdall...${NC}"
docker restart heimdall

sleep 5

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Heimdall is configured!${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo -e "Access your dashboard at: ${GREEN}http://$RPI_IP:80${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The dashboard is public (no login required)."
echo "You can customize icons and layouts directly in the web interface."
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
