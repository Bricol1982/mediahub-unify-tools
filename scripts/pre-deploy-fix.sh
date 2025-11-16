#!/bin/bash
# MediaHub Pre-Deployment Fix Script
# Fixes all critical issues before deployment to Raspberry Pi

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  MediaHub Pre-Deployment Fix"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cd "$PROJECT_ROOT"

# ===========================================
# 1. Create all missing config directories
# ===========================================
log_info "Creating missing config directories..."

SERVICES=(
    "apprise" "bazarr" "duplicati" "gluetun" "gotify"
    "heimdall" "homarr" "jellyfin" "jellyseerr" "komga"
    "lidarr" "mylar3" "navidrome" "netdata" "notifiarr"
    "ntfy" "photoprism" "portainer" "prowlarr" "qbittorrent"
    "radarr" "readarr" "recyclarr" "scrutiny" "sonarr"
    "tautulli" "threadfin" "uptime-kuma" "wireguard" "mailrise"
)

for service in "${SERVICES[@]}"; do
    mkdir -p "config/$service"
    touch "config/$service/.gitkeep"
done

# Special directories with subdirectories
mkdir -p config/nginx-proxy-manager/data
mkdir -p config/nginx-proxy-manager/letsencrypt
touch config/nginx-proxy-manager/.gitkeep
touch config/nginx-proxy-manager/data/.gitkeep
touch config/nginx-proxy-manager/letsencrypt/.gitkeep

mkdir -p config/pihole/etc-pihole
mkdir -p config/pihole/etc-dnsmasq.d
touch config/pihole/.gitkeep
touch config/pihole/etc-pihole/.gitkeep
touch config/pihole/etc-dnsmasq.d/.gitkeep

log_info "Created $(find config -type d | wc -l) config directories"

# ===========================================
# 2. Fix script permissions
# ===========================================
log_info "Setting executable permissions on scripts..."
chmod +x scripts/*.sh
log_info "All scripts are now executable"

# ===========================================
# 3. Create notify.sh helper script
# ===========================================
log_info "Creating notify.sh helper script..."
cat > scripts/notify.sh << 'EOF'
#!/bin/bash
# MediaHub Notification Helper
# Usage: ./notify.sh "Title" "Message" [priority]

TITLE="${1:-MediaHub}"
MESSAGE="${2:-Test notification}"
PRIORITY="${3:-normal}"

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

# Load configuration if exists
if [[ -f "$INSTALL_DIR/.env" ]]; then
    source "$INSTALL_DIR/.env"
fi

# Try Gotify first (self-hosted)
if [[ -n "$GOTIFY_TOKEN" ]]; then
    priority_num=5
    [[ "$PRIORITY" == "high" ]] && priority_num=8
    [[ "$PRIORITY" == "urgent" ]] && priority_num=10

    curl -s -X POST "http://localhost:8070/message" \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -F "title=$TITLE" \
        -F "message=$MESSAGE" \
        -F "priority=$priority_num" >/dev/null 2>&1 && echo "✓ Gotify"
fi

# Try ntfy (pub-sub)
curl -s -X POST "http://localhost:8071/mediahub" \
    -H "Title: $TITLE" \
    -H "Priority: ${PRIORITY:-default}" \
    -d "$MESSAGE" >/dev/null 2>&1 && echo "✓ ntfy"

# Try Apprise API
if [[ -n "$APPRISE_CONFIG" ]]; then
    curl -s -X POST "http://localhost:8000/notify/" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$TITLE\", \"body\": \"$MESSAGE\"}" >/dev/null 2>&1 && echo "✓ Apprise"
fi

# Log to file
LOG_FILE="$INSTALL_DIR/logs/notifications.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S')|$PRIORITY|$TITLE|$MESSAGE" >> "$LOG_FILE"

exit 0
EOF
chmod +x scripts/notify.sh
log_info "Created scripts/notify.sh"

# ===========================================
# 4. Create test-notifications.sh
# ===========================================
log_info "Creating test-notifications.sh..."
cat > scripts/test-notifications.sh << 'EOF'
#!/bin/bash
# Test all notification channels

echo "Testing MediaHub Notification Channels..."
echo "========================================="

SCRIPT_DIR="$(dirname "$0")"

# Test each channel
echo ""
echo "1. Testing Gotify (self-hosted push)..."
"$SCRIPT_DIR/notify.sh" "Test Gotify" "This is a test from MediaHub" "normal"

echo ""
echo "2. Testing ntfy (pub-sub)..."
curl -s -X POST "http://localhost:8071/mediahub" \
    -H "Title: Test ntfy" \
    -d "MediaHub notification test" && echo " ✓ Sent"

echo ""
echo "3. Testing Apprise API..."
curl -s -X POST "http://localhost:8000/notify/" \
    -H "Content-Type: application/json" \
    -d '{"title": "Test Apprise", "body": "MediaHub test notification"}' && echo " ✓ Sent"

echo ""
echo "========================================="
echo "Check your notification apps/channels!"
echo ""
echo "Web interfaces:"
echo "  - Gotify: http://localhost:8070"
echo "  - ntfy: http://localhost:8071/mediahub"
echo "  - Apprise: http://localhost:8000"
EOF
chmod +x scripts/test-notifications.sh
log_info "Created scripts/test-notifications.sh"

# ===========================================
# 5. Create change-dashboard.sh
# ===========================================
log_info "Creating change-dashboard.sh..."
cat > scripts/change-dashboard.sh << 'EOF'
#!/bin/bash
# Change the TV kiosk display dashboard

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
KIOSK_SERVICE="mediahub-kiosk"

echo "========================================="
echo "  MediaHub TV Dashboard Selector"
echo "========================================="
echo ""
echo "Available dashboards:"
echo "  1) Homarr (Home Dashboard)"
echo "  2) Jellyfin (Media Player)"
echo "  3) Komga (Comics/Manga)"
echo "  4) Navidrome (Music)"
echo "  5) TV Admin Panel"
echo ""
read -p "Select dashboard [1-5]: " choice

case $choice in
    1)
        URL="http://localhost:7575"
        NAME="Homarr"
        ;;
    2)
        URL="http://localhost:8096"
        NAME="Jellyfin"
        ;;
    3)
        URL="http://localhost:25600"
        NAME="Komga"
        ;;
    4)
        URL="http://localhost:4533"
        NAME="Navidrome"
        ;;
    5)
        URL="http://localhost:8091"
        NAME="TV Admin Panel"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Switching to $NAME..."

# Update kiosk configuration
if [[ -f "/home/pi/.config/openbox/autostart" ]]; then
    sudo sed -i "s|chromium-browser.*|chromium-browser --kiosk --noerrdialogs --disable-infobars --incognito $URL \&|" /home/pi/.config/openbox/autostart
    echo "Updated autostart configuration"
fi

# Restart kiosk if running
if systemctl is-active --quiet $KIOSK_SERVICE 2>/dev/null; then
    echo "Restarting kiosk service..."
    sudo systemctl restart $KIOSK_SERVICE
else
    echo "Kiosk service not running. Changes will apply on next start."
fi

echo ""
echo "✓ Dashboard changed to $NAME"
echo "  URL: $URL"
EOF
chmod +x scripts/change-dashboard.sh
log_info "Created scripts/change-dashboard.sh"

# ===========================================
# 6. Create pre-deployment validation script
# ===========================================
log_info "Creating pre-deploy-check.sh..."
cat > scripts/pre-deploy-check.sh << 'EOF'
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
EOF
chmod +x scripts/pre-deploy-check.sh
log_info "Created scripts/pre-deploy-check.sh"

# ===========================================
# 7. Create .gitignore for sensitive files
# ===========================================
log_info "Updating .gitignore..."
cat >> .gitignore << 'EOF'

# Sensitive files
.env
*.key
*.pem
*.crt
config/*/api_key*
config/*/password*

# Runtime data
config/*/logs/
config/*/cache/
*.db
*.db-shm
*.db-wal
EOF

# ===========================================
# Summary
# ===========================================
echo ""
echo "========================================="
echo "  Pre-Deployment Fix Complete"
echo "========================================="
echo ""
log_info "Created $(find config -name '.gitkeep' | wc -l) config directories"
log_info "Fixed permissions for $(ls scripts/*.sh | wc -l) scripts"
log_info "Created 4 missing helper scripts"
log_info "Added pre-deployment validation"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/pre-deploy-check.sh"
echo "  2. Copy .env.example to .env and configure"
echo "  3. Run: sudo ./scripts/auto-install.sh"
echo ""
EOF
