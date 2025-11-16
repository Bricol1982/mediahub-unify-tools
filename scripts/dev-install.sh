#!/bin/bash
# MediaHub Dev Install - Quick install for testing
# Copies project to /opt/mediahub for rapid testing

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="/opt/mediahub"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  MediaHub Dev Install${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Running without root - will use sudo for /opt${NC}"
    SUDO="sudo"
else
    SUDO=""
fi

# Create install directory
echo -e "${CYAN}→ Creating ${INSTALL_DIR}...${NC}"
$SUDO mkdir -p "$INSTALL_DIR"
$SUDO chown $USER:$USER "$INSTALL_DIR"

# Copy all files
echo -e "${CYAN}→ Copying project files...${NC}"
rsync -av --exclude='.git' --exclude='node_modules' --exclude='__pycache__' \
    "$PROJECT_DIR/" "$INSTALL_DIR/"

# Make scripts executable
echo -e "${CYAN}→ Making scripts executable...${NC}"
chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

# Create symlink for easy access
if [[ ! -L /usr/local/bin/mediahub ]]; then
    echo -e "${CYAN}→ Creating symlink /usr/local/bin/mediahub...${NC}"
    $SUDO ln -sf "$INSTALL_DIR/scripts/start.sh" /usr/local/bin/mediahub 2>/dev/null || true
fi

# Copy .env.example to .env if not exists
if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    echo -e "${CYAN}→ Creating .env from .env.example...${NC}"
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.env"
fi

# Show summary
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Project installed to: ${CYAN}$INSTALL_DIR${NC}"
echo ""
echo -e "Quick commands:"
echo -e "  ${YELLOW}cd $INSTALL_DIR${NC}"
echo -e "  ${YELLOW}./scripts/start.sh${NC}              # Start all services"
echo -e "  ${YELLOW}./scripts/stop.sh${NC}               # Stop all services"
echo -e "  ${YELLOW}./scripts/status.sh${NC}             # Check status"
echo -e "  ${YELLOW}./scripts/install-wizard.sh${NC}     # Run wizard"
echo -e "  ${YELLOW}./scripts/verify-project.sh${NC}     # Verify project"
echo ""
echo -e "Docker commands:"
echo -e "  ${YELLOW}docker compose up -d${NC}            # Start (full mode)"
echo -e "  ${YELLOW}docker compose -f docker-compose.pi3.yml up -d${NC}  # Pi3 mode"
echo -e "  ${YELLOW}docker compose logs -f${NC}          # View logs"
echo ""
echo -e "Welcome page: ${CYAN}http://localhost:8888${NC}"
echo -e "Dashboard:    ${CYAN}http://localhost:7575${NC}"
echo ""
