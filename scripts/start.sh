#!/bin/bash
# Start all MediaHub services
# This script is copied to /opt/mediahub/start.sh during installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR%/scripts}"

# If running from /opt/mediahub
if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    cd "$INSTALL_DIR"
elif [[ -f "/opt/mediahub/docker-compose.yml" ]]; then
    cd /opt/mediahub
else
    echo "Error: Cannot find docker-compose.yml"
    exit 1
fi

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Starting MediaHub Services${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if .env exists
if [[ ! -f ".env" ]]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Check if external HDD is mounted
if ! mountpoint -q /mnt/media 2>/dev/null; then
    echo -e "${YELLOW}Warning: External HDD not mounted at /mnt/media${NC}"
    echo "Some services may fail to start without media storage."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Start services
echo "Starting Docker containers..."
docker compose up -d

# Wait for services to initialize
echo ""
echo "Waiting for services to initialize..."
sleep 10

# Show status
echo ""
echo -e "${GREEN}Services started!${NC}"
echo ""
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | head -20

# Count running services
running=$(docker compose ps --status running --format json 2>/dev/null | jq -s length 2>/dev/null || docker compose ps | grep -c "Up" || echo "0")
total=$(docker compose ps --format json 2>/dev/null | jq -s length 2>/dev/null || docker compose ps | wc -l || echo "0")

echo ""
echo -e "${GREEN}$running services running${NC}"

# Show access URLs
local_ip=$(hostname -I | awk '{print $1}')
echo ""
echo "Access your services:"
echo "  Dashboard: http://$local_ip:7575"
echo "  Jellyfin:  http://$local_ip:8096"
echo ""

# Check VPN status
echo "Checking VPN connection..."
vpn_ip=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
if [[ "$vpn_ip" != "FAILED" ]] && [[ -n "$vpn_ip" ]]; then
    echo -e "${GREEN}VPN connected: $vpn_ip${NC}"
else
    echo -e "${YELLOW}VPN not connected - check Gluetun logs: docker logs gluetun${NC}"
fi

echo ""
echo "View logs: docker compose logs -f [service_name]"
echo "Stop all:  ./stop.sh"
