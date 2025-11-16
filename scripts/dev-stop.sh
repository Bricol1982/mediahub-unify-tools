#!/bin/bash
# Stop MediaHub dev environment

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Stopping MediaHub Dev Environment...${NC}"

docker compose -f docker-compose.dev.yml down

echo -e "${GREEN}✓ Dev environment stopped${NC}"
