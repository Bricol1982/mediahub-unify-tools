#!/bin/bash
# MediaHub Pre-Deployment Validation
# Run this BEFORE installation to verify system readiness

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check_pass() { echo -e "  ${GREEN}✓${NC} $1"; }
check_fail() { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++)); }
check_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }

echo "========================================="
echo "  MediaHub Pre-Deployment Check"
echo "========================================="
echo ""

# 1. Check if Raspberry Pi
echo "1. Hardware Detection"
if [[ -f /proc/device-tree/model ]]; then
    MODEL=$(cat /proc/device-tree/model | tr -d '\0')
    if [[ "$MODEL" == *"Raspberry Pi 4"* ]]; then
        check_pass "Raspberry Pi 4 detected: $MODEL"
    else
        check_warn "Non-RPi4 device: $MODEL (may work but not tested)"
    fi
else
    check_warn "Not a Raspberry Pi (or /proc/device-tree not available)"
fi

# 2. Check RAM
echo ""
echo "2. Memory Check"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM -ge 7500 ]]; then
    check_pass "RAM: ${TOTAL_RAM}MB (8GB system)"
elif [[ $TOTAL_RAM -ge 3500 ]]; then
    check_warn "RAM: ${TOTAL_RAM}MB (4GB - some services may be slow)"
else
    check_fail "RAM: ${TOTAL_RAM}MB (Minimum 4GB required)"
fi

# 3. Check disk space
echo ""
echo "3. Disk Space"
ROOT_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $ROOT_SPACE -ge 20 ]]; then
    check_pass "Root partition: ${ROOT_SPACE}GB free"
else
    check_fail "Root partition: ${ROOT_SPACE}GB free (minimum 20GB needed)"
fi

# 4. Check for external HDD
echo ""
echo "4. External Storage"
if mountpoint -q /mnt/media 2>/dev/null; then
    MEDIA_SPACE=$(df -BG /mnt/media | awk 'NR==2 {print $4}' | sed 's/G//')
    check_pass "External HDD mounted at /mnt/media (${MEDIA_SPACE}GB free)"
else
    check_warn "No HDD at /mnt/media (run install to configure)"
fi

# 5. Check Docker
echo ""
echo "5. Docker Installation"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    check_pass "Docker installed: $DOCKER_VERSION"
else
    check_warn "Docker not installed (will be installed during setup)"
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    check_pass "Docker Compose available"
else
    check_warn "Docker Compose not available (will be installed)"
fi

# 6. Check network connectivity
echo ""
echo "6. Network Connectivity"
if ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
    check_pass "Internet connection working"
else
    check_fail "No internet connection"
fi

if ping -c 1 -W 3 github.com &> /dev/null; then
    check_pass "Can reach GitHub"
else
    check_warn "Cannot reach GitHub (may affect updates)"
fi

# 7. Check ports availability
echo ""
echo "7. Port Availability"
CRITICAL_PORTS=(80 443 8096 7575 9091 8091)
for port in "${CRITICAL_PORTS[@]}"; do
    if ! ss -tuln | grep -q ":$port "; then
        check_pass "Port $port available"
    else
        check_warn "Port $port in use"
    fi
done

# 8. Check .env file
echo ""
echo "8. Configuration Files"
if [[ -f ".env" ]]; then
    check_pass ".env file exists"

    # Check critical variables
    source .env
    [[ -n "$PUID" ]] && check_pass "PUID set: $PUID" || check_warn "PUID not set"
    [[ -n "$PGID" ]] && check_pass "PGID set: $PGID" || check_warn "PGID not set"
    [[ -n "$TZ" ]] && check_pass "Timezone set: $TZ" || check_warn "TZ not set"
    [[ -n "$CONFIG_PATH" ]] && check_pass "CONFIG_PATH: $CONFIG_PATH" || check_warn "CONFIG_PATH not set"
    [[ -n "$MEDIA_PATH" ]] && check_pass "MEDIA_PATH: $MEDIA_PATH" || check_warn "MEDIA_PATH not set"
else
    check_warn ".env file not found (copy from .env.example)"
fi

# Summary
echo ""
echo "========================================="
echo "  Summary"
echo "========================================="
if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}All checks passed! Ready for deployment.${NC}"
    else
        echo -e "${YELLOW}$WARNINGS warnings found. Deployment may proceed with caution.${NC}"
    fi
else
    echo -e "${RED}$ERRORS critical errors found. Fix these before deployment.${NC}"
fi
echo ""

exit $ERRORS
