#!/bin/bash
# MediaHub Project Coherence Verification
# Checks that all components are properly configured

# Don't use set -e as we need to continue on check failures
# set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
PASSED=0

log_pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++)); }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
log_info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

echo ""
echo "========================================="
echo "  MediaHub Project Verification"
echo "========================================="
echo ""

cd "$PROJECT_DIR"

# ===========================================
# 1. Check Essential Files
# ===========================================
echo -e "${BLUE}1. Essential Files${NC}"

if [[ -f "docker-compose.yml" ]]; then log_pass "docker-compose.yml exists"; else log_fail "docker-compose.yml MISSING"; fi
if [[ -f ".env.example" ]]; then log_pass ".env.example exists"; else log_fail ".env.example MISSING"; fi
if [[ -f "README.md" ]]; then log_pass "README.md exists"; else log_fail "README.md MISSING"; fi
if [[ -f ".gitignore" ]]; then log_pass ".gitignore exists"; else log_warn ".gitignore missing"; fi

# ===========================================
# 2. Check Scripts
# ===========================================
echo ""
echo -e "${BLUE}2. Installation Scripts${NC}"

REQUIRED_SCRIPTS=(
    "auto-install.sh"
    "install-wizard.sh"
    "install.sh"
    "start.sh"
    "stop.sh"
    "status.sh"
    "post-install-setup.sh"
    "setup-notifications.sh"
    "setup-jellyfin.sh"
    "setup-indexers.sh"
    "setup-vpn.sh"
    "pre-deploy-check.sh"
    "backup-config.sh"
    "health-check.sh"
    "notify.sh"
    "test-notifications.sh"
    "change-dashboard.sh"
    "show-passwords.sh"
    "system-alerts.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ -f "scripts/$script" ]]; then
        if [[ -x "scripts/$script" ]]; then
            log_pass "$script (executable)"
        else
            log_warn "$script exists but not executable"
        fi
    else
        log_fail "$script MISSING"
    fi
done

# ===========================================
# 3. Check Config Directories
# ===========================================
echo ""
echo -e "${BLUE}3. Configuration Directories${NC}"

CONFIG_DIRS=(
    "apprise" "bazarr" "cec" "duplicati" "gluetun"
    "gotify" "heimdall" "homarr" "iptv" "jellyfin"
    "jellyseerr" "komga" "lidarr" "mailrise" "mylar3"
    "navidrome" "netdata" "nginx-proxy-manager" "notifiarr"
    "ntfy" "photoprism" "pihole" "portainer" "prowlarr"
    "qbittorrent" "radarr" "readarr" "recyclarr" "scrutiny"
    "sonarr" "tautulli" "threadfin" "tv-admin" "uptime-kuma"
    "welcome" "wireguard"
)

missing_dirs=0
for dir in "${CONFIG_DIRS[@]}"; do
    if [[ ! -d "config/$dir" ]]; then
        ((missing_dirs++))
    fi
done

if [[ $missing_dirs -eq 0 ]]; then
    log_pass "All ${#CONFIG_DIRS[@]} config directories present"
else
    log_fail "$missing_dirs config directories missing"
fi

# ===========================================
# 4. Check Docker Compose Syntax
# ===========================================
echo ""
echo -e "${BLUE}4. Docker Compose Configuration${NC}"

if command -v docker &> /dev/null; then
    # Check syntax without requiring all variables (some use :? which requires values)
    compose_output=$(docker compose config 2>&1)
    if echo "$compose_output" | grep -q "error"; then
        # Check if it's just missing env variables (expected without .env)
        if echo "$compose_output" | grep -q "required variable.*is missing a value"; then
            log_pass "docker-compose.yml syntax valid (requires .env for :? variables)"
        else
            log_fail "docker-compose.yml has syntax errors"
        fi
    else
        log_pass "docker-compose.yml syntax valid"
    fi
else
    log_warn "Docker not installed, skipping compose validation"
fi

# Count services
SERVICE_COUNT=$(grep -E "^  [a-z].*:$" docker-compose.yml | grep -v "environment:" | wc -l)
log_info "Found $SERVICE_COUNT services defined"

# ===========================================
# 5. Check Environment Variables
# ===========================================
echo ""
echo -e "${BLUE}5. Environment Variables (.env.example)${NC}"

REQUIRED_ENV_VARS=(
    "PUID"
    "PGID"
    "TZ"
    "CONFIG_PATH"
    "MEDIA_PATH"
    "DOWNLOAD_PATH"
    "PROTON_USER"
    "PROTON_PASS"
    "JELLYFIN_PASSWORD"
    "GOTIFY_PASSWORD"
    "PHOTOPRISM_ADMIN_PASSWORD"
)

missing_vars=0
for var in "${REQUIRED_ENV_VARS[@]}"; do
    if ! grep -q "^$var=" .env.example; then
        log_warn "$var not in .env.example"
        ((missing_vars++))
    fi
done

if [[ $missing_vars -eq 0 ]]; then
    log_pass "All critical env variables present"
else
    log_warn "$missing_vars variables should be added to .env.example"
fi

# Check for hardcoded sensitive defaults
if grep -q ":-changeme" docker-compose.yml; then
    log_fail "Hardcoded 'changeme' defaults found in docker-compose.yml"
else
    log_pass "No insecure default passwords"
fi

# ===========================================
# 6. Check TV Admin Interface
# ===========================================
echo ""
echo -e "${BLUE}6. TV Admin Interface${NC}"

if [[ -f "config/tv-admin/index.html" ]]; then
    log_pass "TV Admin HTML exists"

    # Check for key features
    if grep -q "playFeedback" config/tv-admin/index.html; then
        log_pass "Audio feedback implemented"
    else
        log_warn "Audio feedback missing"
    fi

    if grep -q "scrollToFocused" config/tv-admin/index.html; then
        log_pass "Smooth scroll implemented"
    else
        log_warn "Smooth scroll missing"
    fi

    if grep -q "updatePositionIndicator" config/tv-admin/index.html; then
        log_pass "Position indicator implemented"
    else
        log_warn "Position indicator missing"
    fi
else
    log_fail "TV Admin interface MISSING"
fi

if [[ -f "config/tv-admin/server.py" ]]; then
    log_pass "TV Admin backend exists"
else
    log_fail "TV Admin backend MISSING"
fi

# ===========================================
# 7. Check Welcome Page
# ===========================================
echo ""
echo -e "${BLUE}7. First-Use Welcome Page${NC}"

if [[ -f "config/welcome/index.html" ]]; then
    log_pass "Welcome page exists"

    if grep -q "progress-steps" config/welcome/index.html; then
        log_pass "Step-by-step wizard implemented"
    else
        log_warn "Wizard steps not found"
    fi
else
    log_warn "Welcome page not created yet"
fi

# ===========================================
# 8. Check Documentation
# ===========================================
echo ""
echo -e "${BLUE}8. Documentation${NC}"

# Check README sections
README_SECTIONS=(
    "Installation"
    "Configuration"
    "Notifications"
    "VPN"
    "Jellyfin"
)

for section in "${README_SECTIONS[@]}"; do
    if grep -qi "$section" README.md; then
        log_pass "README includes '$section' section"
    else
        log_warn "README missing '$section' section"
    fi
done

# ===========================================
# 9. Check Script Cross-References
# ===========================================
echo ""
echo -e "${BLUE}9. Script Dependencies${NC}"

# Check that scripts reference each other correctly
if grep -q "post-install-setup.sh" scripts/auto-install.sh; then
    log_pass "auto-install.sh calls post-install-setup.sh"
else
    log_fail "auto-install.sh missing post-install integration"
fi

if grep -q "setup-jellyfin.sh" scripts/post-install-setup.sh; then
    log_pass "post-install-setup.sh calls setup-jellyfin.sh"
else
    log_warn "post-install-setup.sh doesn't call setup-jellyfin.sh"
fi

# ===========================================
# 10. Security Checks
# ===========================================
echo ""
echo -e "${BLUE}10. Security Configuration${NC}"

# Check for security features
if grep -q "ufw" scripts/install-wizard.sh scripts/auto-install.sh 2>/dev/null; then
    log_pass "Firewall (UFW) configuration present"
else
    log_warn "Firewall configuration not found"
fi

if grep -q "fail2ban" scripts/install-wizard.sh scripts/auto-install.sh 2>/dev/null; then
    log_pass "Fail2ban configuration present"
else
    log_warn "Fail2ban configuration not found"
fi

if grep -q "openssl.*enc" scripts/install-wizard.sh 2>/dev/null; then
    log_pass "Password encryption implemented"
else
    log_warn "Password encryption not found"
fi

if grep -q "chmod 600" scripts/*.sh 2>/dev/null; then
    log_pass "Secure file permissions enforced"
else
    log_warn "File permission hardening not found"
fi

# ===========================================
# Summary
# ===========================================
echo ""
echo "========================================="
echo "  Verification Summary"
echo "========================================="
echo ""
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "  ${RED}Errors: $ERRORS${NC}"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ Project is FULLY COHERENT and ready for deployment!${NC}"
    else
        echo -e "${YELLOW}⚠️  Project is MOSTLY READY with some minor issues.${NC}"
    fi
else
    echo -e "${RED}❌ Project has CRITICAL ISSUES that must be fixed.${NC}"
fi

echo ""
echo "Total scripts: $(ls scripts/*.sh 2>/dev/null | wc -l)"
echo "Total config dirs: $(find config -type d | wc -l)"
echo ""

# Check for show-passwords.sh which will be created by install-wizard
if [[ ! -f "scripts/show-passwords.sh" ]]; then
    log_info "Note: show-passwords.sh will be created during installation"
fi

exit $ERRORS
