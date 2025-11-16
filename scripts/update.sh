#!/bin/bash
# Update all MediaHub Docker images
# This script is copied to /opt/mediahub/update.sh during installation

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
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  MediaHub Update${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check disk space
free_space=$(df -BG /var/lib/docker 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ -n "$free_space" ]] && [[ $free_space -lt 5 ]]; then
    echo -e "${RED}Warning: Low disk space (${free_space}GB free)${NC}"
    echo "Consider cleaning up: docker image prune -a"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Backup current state
echo "Creating configuration backup before update..."
if [[ -f "scripts/backup-config.sh" ]]; then
    ./scripts/backup-config.sh --quick 2>/dev/null || echo "Backup skipped"
fi
echo ""

# Pull new images
echo -e "${BLUE}Pulling latest Docker images...${NC}"
echo "This may take several minutes depending on your connection."
echo ""

docker compose pull 2>&1 | while read line; do
    if echo "$line" | grep -q "Pulling\|Downloaded\|Pull complete\|Already"; then
        echo "$line"
    fi
done

echo ""

# Check for updates
echo "Checking for updated images..."
updates=$(docker compose pull --dry-run 2>&1 | grep -c "Pull" || echo "0")

if [[ "$updates" == "0" ]]; then
    echo -e "${GREEN}All images are already up to date!${NC}"
else
    echo -e "${YELLOW}$updates image(s) will be updated${NC}"
fi
echo ""

# Recreate containers
read -p "Recreate containers with new images? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Stopping current containers..."
    docker compose down

    echo ""
    echo "Starting containers with updated images..."
    docker compose up -d

    echo ""
    echo "Waiting for services to start..."
    sleep 10

    # Cleanup old images
    echo ""
    echo "Cleaning up old images..."
    docker image prune -f

    echo ""
    echo -e "${GREEN}Update complete!${NC}"

    # Show status
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -15
else
    echo "Update cancelled. Images are downloaded but containers not recreated."
    echo "Run './start.sh' to apply updates later."
fi

echo ""
echo "Check service health: ./status.sh"
echo "View update logs: docker compose logs --tail=50"
