#!/bin/bash
# Start all MediaHub services
# This script is copied to /opt/mediahub/start.sh during installation

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
RED='\033[0;31m'
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

# Check for Docker layer errors and clean if necessary
echo "Checking Docker health..."
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker Compose configuration valid${NC}"
else
    echo -e "${RED}✗ Docker Compose configuration error${NC}"
    echo "Please check your docker-compose.yml and .env files"
    exit 1
fi

# Pre-check: verify if images exist or need to be pulled
echo "Verifying Docker images..."
missing_images=false

# Quick test to see if there are layer errors
if docker compose ps 2>&1 | grep -q "layer does not exist\|no such image"; then
    echo -e "${RED}✗ Docker layer corruption detected${NC}"
    echo ""
    echo "This usually happens when Docker data was partially deleted."
    echo "To fix this, run:"
    echo ""
    echo -e "  ${YELLOW}sudo systemctl stop docker${NC}"
    echo -e "  ${YELLOW}sudo rm -rf /var/lib/docker${NC}"
    echo -e "  ${YELLOW}sudo mkdir -p /var/lib/docker${NC}"
    echo -e "  ${YELLOW}sudo systemctl start docker${NC}"
    echo ""
    echo "Then re-run the installation wizard to download images properly:"
    echo -e "  ${YELLOW}sudo ./scripts/install-wizard-verbose.sh${NC}"
    exit 1
fi

# Start services with error handling
echo "Starting Docker containers..."
if ! docker compose up -d 2>&1 | tee /tmp/docker_start.log; then
    # Check for specific errors
    if grep -q "layer does not exist\|no such image" /tmp/docker_start.log; then
        echo ""
        echo -e "${RED}✗ Docker image corruption detected${NC}"
        echo "Some Docker layers are missing. This requires a clean reinstall."
        echo ""
        echo "Quick fix:"
        echo -e "  ${YELLOW}docker system prune -a -f${NC}"
        echo ""
        echo "Or full reinstall:"
        echo -e "  ${YELLOW}sudo ./scripts/install-wizard-verbose.sh${NC}"
        rm -f /tmp/docker_start.log
        exit 1
    elif grep -q "no space left on device" /tmp/docker_start.log; then
        echo ""
        echo -e "${RED}✗ No space left on device${NC}"
        echo "Your disk is full. Check available space:"
        echo -e "  ${YELLOW}df -h${NC}"
        rm -f /tmp/docker_start.log
        exit 1
    fi
fi
rm -f /tmp/docker_start.log

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
