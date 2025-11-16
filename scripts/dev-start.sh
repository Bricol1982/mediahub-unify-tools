#!/bin/bash
# Quick start for MediaHub dev environment

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Starting MediaHub Dev Environment...${NC}"
echo ""

# Check if dev-data exists
if [[ ! -d "$PROJECT_DIR/dev-data" ]]; then
    echo "Running initial setup..."
    ./scripts/dev-setup.sh
fi

# Start containers
docker compose -f docker-compose.dev.yml up -d

echo ""
echo -e "${GREEN}✓ Dev environment started!${NC}"
echo ""
echo "Services:"
echo -e "  Welcome: ${CYAN}http://localhost:8888${NC}"
echo -e "  Homarr:  ${CYAN}http://localhost:7575${NC}"
echo ""
echo "View logs: docker compose -f docker-compose.dev.yml logs -f"
