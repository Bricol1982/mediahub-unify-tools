#!/bin/bash
# Clean MediaHub dev environment (remove all dev data)

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DATA_DIR="$PROJECT_DIR/dev-data"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}=========================================${NC}"
echo -e "${RED}  MediaHub Dev Environment Cleanup${NC}"
echo -e "${RED}=========================================${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "  - Stop all dev containers"
echo "  - Remove all dev data in $DEV_DATA_DIR"
echo "  - Remove .env file"
echo ""

read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

# Stop containers first
echo -e "${YELLOW}→ Stopping containers...${NC}"
cd "$PROJECT_DIR"
docker compose -f docker-compose.dev.yml down -v 2>/dev/null || true

# Remove dev data
if [[ -d "$DEV_DATA_DIR" ]]; then
    echo -e "${YELLOW}→ Removing dev data...${NC}"
    rm -rf "$DEV_DATA_DIR"
    echo -e "${GREEN}✓ Dev data removed${NC}"
fi

# Optionally remove .env
if [[ -f "$PROJECT_DIR/.env" ]]; then
    read -p "Remove .env file? (y/n): " remove_env
    if [[ "$remove_env" == "y" ]]; then
        rm -f "$PROJECT_DIR/.env"
        echo -e "${GREEN}✓ .env removed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Dev environment cleaned${NC}"
echo "Run ./scripts/dev-setup.sh to recreate it."
