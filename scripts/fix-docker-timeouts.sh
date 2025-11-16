#!/bin/bash
# Fix Docker download timeouts for Raspberry Pi
# Reduces concurrent downloads and increases retry attempts

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  FIXING DOCKER DOWNLOAD TIMEOUTS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (sudo)${NC}"
   exit 1
fi

# Create Docker config directory if it doesn't exist
echo -e "→ Creating Docker configuration directory..."
mkdir -p /etc/docker

# Backup existing config if present
if [[ -f /etc/docker/daemon.json ]]; then
    echo -e "→ Backing up existing configuration..."
    cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓ Backup created${NC}"
fi

# Create optimized Docker daemon configuration
echo -e "→ Creating optimized Docker daemon configuration..."
cat > /etc/docker/daemon.json << 'EOF'
{
  "max-concurrent-downloads": 2,
  "max-concurrent-uploads": 2,
  "max-download-attempts": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

# Show the configuration
echo -e "Configuration applied:"
echo -e "  ${YELLOW}max-concurrent-downloads: 2${NC} (reduced from default 3)"
echo -e "  ${YELLOW}max-download-attempts: 10${NC} (increased from default 5)"
echo -e "  ${YELLOW}log rotation: 10MB x 3 files${NC} (prevents disk fill)"
echo ""

# Restart Docker
echo -e "→ Restarting Docker daemon..."
systemctl restart docker

# Wait for Docker to be ready
echo -e "→ Waiting for Docker to be ready..."
sleep 5

# Verify Docker is running
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker daemon restarted successfully${NC}"
else
    echo -e "${RED}✗ Docker failed to restart${NC}"
    echo -e "${YELLOW}Check logs with: journalctl -u docker${NC}"
    exit 1
fi

# Verify configuration
echo ""
echo -e "→ Verifying configuration..."
docker info 2>/dev/null | grep -E "Max Concurrent Downloads|Storage Driver" || true

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  CONFIGURATION COMPLETE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "You can now retry starting MediaHub:"
echo -e "  ${YELLOW}cd /opt/mediahub && sudo docker compose up -d${NC}"
echo ""
echo -e "If you still experience timeouts, try pulling images individually:"
echo -e "  ${YELLOW}sudo docker pull lscr.io/linuxserver/jellyfin:latest${NC}"
echo ""
