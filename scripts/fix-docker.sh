#!/bin/bash
# Fix Docker layer corruption and reset Docker storage
# Use this when you see "layer does not exist" or "no such image" errors

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  MediaHub Docker Repair Tool${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (sudo)${NC}"
   exit 1
fi

# Detect current Docker root
CURRENT_ROOT=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}' || echo "/var/lib/docker")
echo -e "Current Docker Root: ${YELLOW}$CURRENT_ROOT${NC}"

# Check if HDD is mounted
HDD_MOUNTED=false
if mountpoint -q /mnt/media 2>/dev/null; then
    HDD_MOUNTED=true
    echo -e "External HDD: ${GREEN}Mounted at /mnt/media${NC}"
    df -h /mnt/media | tail -1
else
    echo -e "External HDD: ${YELLOW}Not mounted${NC}"
fi

echo ""
echo -e "${YELLOW}WARNING: This will delete ALL Docker data including:${NC}"
echo "  - All Docker images"
echo "  - All Docker containers"
echo "  - All Docker volumes"
echo "  - All Docker networks"
echo ""

if [[ "$HDD_MOUNTED" == "true" ]]; then
    echo -e "${GREEN}After reset, Docker will use /mnt/media/docker (HDD)${NC}"
else
    echo -e "${YELLOW}After reset, Docker will use /var/lib/docker (SD card)${NC}"
    echo -e "${RED}WARNING: SD card may run out of space!${NC}"
fi

echo ""
read -p "Are you sure you want to continue? (yes/NO) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Step 1: Stopping all Docker services...${NC}"
systemctl stop docker.socket 2>/dev/null || true
systemctl stop docker 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true
killall dockerd 2>/dev/null || true
killall containerd 2>/dev/null || true
sleep 3
echo -e "${GREEN}✓ Docker services stopped${NC}"

echo ""
echo -e "${BLUE}Step 2: Unmounting Docker overlays...${NC}"
umount -l /var/lib/docker/overlay2/*/merged 2>/dev/null || true
umount -l /var/lib/docker/rootfs/overlayfs/* 2>/dev/null || true
if [[ "$HDD_MOUNTED" == "true" ]]; then
    umount -l /mnt/media/docker/overlay2/*/merged 2>/dev/null || true
fi
echo -e "${GREEN}✓ Overlays unmounted${NC}"

echo ""
echo -e "${BLUE}Step 3: Removing Docker data...${NC}"
rm -rf /var/lib/docker
mkdir -p /var/lib/docker
if [[ "$HDD_MOUNTED" == "true" ]]; then
    rm -rf /mnt/media/docker
    mkdir -p /mnt/media/docker
    chown root:root /mnt/media/docker
    chmod 711 /mnt/media/docker
fi
echo -e "${GREEN}✓ Docker data removed${NC}"

echo ""
echo -e "${BLUE}Step 4: Configuring Docker...${NC}"
mkdir -p /etc/docker

if [[ "$HDD_MOUNTED" == "true" ]]; then
    DOCKER_ROOT="/mnt/media/docker"
else
    DOCKER_ROOT="/var/lib/docker"
fi

cat > /etc/docker/daemon.json << EOF
{
  "data-root": "$DOCKER_ROOT",
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
echo -e "${GREEN}✓ Docker configured to use: $DOCKER_ROOT${NC}"

echo ""
echo -e "${BLUE}Step 5: Starting Docker...${NC}"
systemctl start docker
sleep 3

# Verify
ACTUAL_ROOT=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}')
if [[ "$ACTUAL_ROOT" == "$DOCKER_ROOT" ]]; then
    echo -e "${GREEN}✓ Docker is now using: $ACTUAL_ROOT${NC}"
else
    echo -e "${YELLOW}Warning: Docker Root is $ACTUAL_ROOT (expected $DOCKER_ROOT)${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Docker Reset Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo ""
if [[ -f "/opt/mediahub/docker-compose.yml" ]]; then
    echo "1. Re-download all Docker images:"
    echo -e "   ${YELLOW}cd /opt/mediahub && docker compose pull${NC}"
    echo ""
    echo "2. Start MediaHub services:"
    echo -e "   ${YELLOW}cd /opt/mediahub && docker compose up -d${NC}"
else
    echo "Run the installation wizard to set up MediaHub:"
    echo -e "   ${YELLOW}sudo ./scripts/install-wizard-verbose.sh${NC}"
fi

echo ""
echo "Available disk space:"
df -h / /mnt/media 2>/dev/null | grep -v "^Filesystem" || df -h /
echo ""
