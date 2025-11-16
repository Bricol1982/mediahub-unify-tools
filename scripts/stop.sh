#!/bin/bash
# Stop all MediaHub services
# This script is copied to /opt/mediahub/stop.sh during installation

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

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Stopping MediaHub Services${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Show current status
echo "Currently running services:"
docker compose ps --status running --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps | grep "Up"
echo ""

# Ask for confirmation
read -p "Stop all services? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Stop services
echo "Stopping containers..."
docker compose down

echo ""
echo -e "${GREEN}All services stopped${NC}"
echo ""
echo "To start again: ./start.sh"
