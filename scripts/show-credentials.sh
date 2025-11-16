#!/bin/bash
# MediaHub Credentials Viewer
# Displays all generated passwords and service credentials

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Run the installation wizard first to generate credentials."
    exit 1
fi

# Load .env
source "$ENV_FILE"

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ${BOLD}MEDIAHUB CREDENTIALS${NC}${CYAN}                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Info
echo -e "${MAGENTA}═══ SYSTEM INFO ═══${NC}"
echo -e "  Install Directory: ${CYAN}${INSTALL_DIR:-/opt/mediahub}${NC}"
echo -e "  User ID (PUID):    ${CYAN}${PUID:-1000}${NC}"
echo -e "  Group ID (PGID):   ${CYAN}${PGID:-1000}${NC}"
echo -e "  Timezone:          ${CYAN}${TZ:-Europe/Paris}${NC}"
echo ""

# VPN Configuration
echo -e "${MAGENTA}═══ VPN CONFIGURATION ═══${NC}"
if [[ "$VPN_SERVICE_PROVIDER" == "none" ]] || [[ -z "$VPN_SERVICE_PROVIDER" ]]; then
    echo -e "  Status:   ${RED}NOT CONFIGURED${NC}"
    echo -e "  ${YELLOW}⚠ Run ./scripts/setup-vpn.sh to configure VPN${NC}"
else
    echo -e "  Provider: ${GREEN}$VPN_SERVICE_PROVIDER${NC}"
    echo -e "  Type:     ${CYAN}${VPN_TYPE:-openvpn}${NC}"
    if [[ -n "$OPENVPN_USER" ]]; then
        echo -e "  Username: ${CYAN}$OPENVPN_USER${NC}"
        echo -e "  Password: ${YELLOW}***hidden***${NC} (check .env file)"
    fi
    if [[ -n "$SERVER_COUNTRIES" ]]; then
        echo -e "  Country:  ${CYAN}$SERVER_COUNTRIES${NC}"
    fi
fi
echo ""

# Service Credentials
echo -e "${MAGENTA}═══ SERVICE CREDENTIALS ═══${NC}"
echo ""

# Jellyfin
echo -e "${BLUE}📺 Jellyfin${NC} (http://localhost:8096)"
echo -e "   User:     ${GREEN}${JELLYFIN_USER:-admin}${NC}"
echo -e "   Password: ${GREEN}${JELLYFIN_PASSWORD:-<not set>}${NC}"
echo ""

# qBittorrent
echo -e "${BLUE}⬇️  qBittorrent${NC} (http://localhost:8080)"
echo -e "   User:     ${GREEN}${QBITTORRENT_USER:-admin}${NC}"
echo -e "   Password: ${GREEN}${QBITTORRENT_PASSWORD:-adminadmin}${NC}"
echo ""

# Photoprism
if [[ -n "$PHOTOPRISM_ADMIN_PASSWORD" ]]; then
    echo -e "${BLUE}📷 Photoprism${NC} (http://localhost:2342)"
    echo -e "   User:     ${GREEN}${PHOTOPRISM_ADMIN_USER:-admin}${NC}"
    echo -e "   Password: ${GREEN}$PHOTOPRISM_ADMIN_PASSWORD${NC}"
    echo ""
fi

# Gotify
if [[ -n "$GOTIFY_PASSWORD" ]]; then
    echo -e "${BLUE}🔔 Gotify${NC} (http://localhost:8070)"
    echo -e "   User:     ${GREEN}${GOTIFY_USER:-admin}${NC}"
    echo -e "   Password: ${GREEN}$GOTIFY_PASSWORD${NC}"
    echo ""
fi

# Pi-hole
if [[ -n "$PIHOLE_PASSWORD" ]]; then
    echo -e "${BLUE}🛡️  Pi-hole${NC} (http://localhost:8053/admin)"
    echo -e "   Password: ${GREEN}$PIHOLE_PASSWORD${NC}"
    echo ""
fi

# Services without auth (API key based)
echo -e "${MAGENTA}═══ API-KEY BASED SERVICES ═══${NC}"
echo -e "${YELLOW}These services use API keys, configure auth in their web UI:${NC}"
echo ""

echo -e "${BLUE}📺 Sonarr${NC}     http://localhost:8989"
if [[ -n "$SONARR_API_KEY" ]] && [[ "$SONARR_API_KEY" != "your_sonarr_api_key" ]]; then
    echo -e "   API Key: ${GREEN}$SONARR_API_KEY${NC}"
fi
echo ""

echo -e "${BLUE}🎬 Radarr${NC}     http://localhost:7878"
if [[ -n "$RADARR_API_KEY" ]] && [[ "$RADARR_API_KEY" != "your_radarr_api_key" ]]; then
    echo -e "   API Key: ${GREEN}$RADARR_API_KEY${NC}"
fi
echo ""

echo -e "${BLUE}🎵 Lidarr${NC}     http://localhost:8686"
if [[ -n "$LIDARR_API_KEY" ]] && [[ "$LIDARR_API_KEY" != "your_lidarr_api_key" ]]; then
    echo -e "   API Key: ${GREEN}$LIDARR_API_KEY${NC}"
fi
echo ""

echo -e "${BLUE}🔍 Prowlarr${NC}   http://localhost:9696"
echo ""

echo -e "${BLUE}💬 Bazarr${NC}     http://localhost:6767"
echo ""

# Other Services
echo -e "${MAGENTA}═══ OTHER SERVICES ═══${NC}"
echo -e "${BLUE}🏠 Homarr${NC}     http://localhost:7575  (Dashboard)"
echo -e "${BLUE}📊 Netdata${NC}    http://localhost:19999 (Monitoring)"
echo -e "${BLUE}📈 Uptime Kuma${NC} http://localhost:3001 (Status monitoring)"
echo -e "${BLUE}📚 Komga${NC}      http://localhost:25600 (Comics/Manga)"
echo -e "${BLUE}🎥 Threadfin${NC}  http://localhost:34400 (IPTV proxy)"
echo ""

# Storage Paths
echo -e "${MAGENTA}═══ STORAGE PATHS ═══${NC}"
echo -e "  Config:    ${CYAN}${CONFIG_PATH:-/opt/mediahub/config}${NC}"
echo -e "  Downloads: ${CYAN}${DOWNLOAD_PATH:-/mnt/media/downloads}${NC}"
echo -e "  Media:     ${CYAN}${MEDIA_PATH:-/mnt/media/library}${NC}"
echo -e "  Backups:   ${CYAN}${BACKUP_PATH:-/opt/mediahub/backups}${NC}"
echo ""

# Security Warning
echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ⚠️  SECURITY WARNING                                      ║${NC}"
echo -e "${RED}║  These credentials are stored in plain text in .env       ║${NC}"
echo -e "${RED}║  Keep this file secure and never share it publicly!       ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Save to file option
read -p "Save credentials to file? (y/n): " save_choice
if [[ "$save_choice" == "y" ]]; then
    CREDS_FILE="$PROJECT_DIR/CREDENTIALS.txt"
    cat > "$CREDS_FILE" << EOF
MediaHub Credentials
Generated: $(date)
===========================================

SYSTEM INFO
-----------
Install Directory: ${INSTALL_DIR:-/opt/mediahub}
User ID (PUID): ${PUID:-1000}
Group ID (PGID): ${PGID:-1000}
Timezone: ${TZ:-Europe/Paris}

VPN CONFIGURATION
-----------------
Provider: ${VPN_SERVICE_PROVIDER:-none}
Type: ${VPN_TYPE:-none}
Username: ${OPENVPN_USER:-<not set>}
Country: ${SERVER_COUNTRIES:-<not set>}

SERVICE CREDENTIALS
-------------------
Jellyfin (http://localhost:8096)
  User: ${JELLYFIN_USER:-admin}
  Password: ${JELLYFIN_PASSWORD:-<not set>}

qBittorrent (http://localhost:8080)
  User: ${QBITTORRENT_USER:-admin}
  Password: ${QBITTORRENT_PASSWORD:-adminadmin}

Photoprism (http://localhost:2342)
  User: ${PHOTOPRISM_ADMIN_USER:-admin}
  Password: ${PHOTOPRISM_ADMIN_PASSWORD:-<not set>}

Gotify (http://localhost:8070)
  User: ${GOTIFY_USER:-admin}
  Password: ${GOTIFY_PASSWORD:-<not set>}

Pi-hole (http://localhost:8053/admin)
  Password: ${PIHOLE_PASSWORD:-<not set>}

API KEYS
--------
Sonarr: ${SONARR_API_KEY:-<not set>}
Radarr: ${RADARR_API_KEY:-<not set>}
Lidarr: ${LIDARR_API_KEY:-<not set>}

SERVICE URLs
------------
Jellyfin:     http://localhost:8096
Sonarr:       http://localhost:8989
Radarr:       http://localhost:7878
Lidarr:       http://localhost:8686
Prowlarr:     http://localhost:9696
Bazarr:       http://localhost:6767
qBittorrent:  http://localhost:8080
Homarr:       http://localhost:7575
Netdata:      http://localhost:19999
Uptime Kuma:  http://localhost:3001
Komga:        http://localhost:25600
Threadfin:    http://localhost:34400
Photoprism:   http://localhost:2342
Gotify:       http://localhost:8070
Pi-hole:      http://localhost:8053/admin

STORAGE PATHS
-------------
Config: ${CONFIG_PATH:-/opt/mediahub/config}
Downloads: ${DOWNLOAD_PATH:-/mnt/media/downloads}
Media: ${MEDIA_PATH:-/mnt/media/library}
Backups: ${BACKUP_PATH:-/opt/mediahub/backups}

===========================================
⚠️ KEEP THIS FILE SECURE - DO NOT SHARE!
===========================================
EOF
    chmod 600 "$CREDS_FILE"
    echo -e "${GREEN}✓ Credentials saved to: $CREDS_FILE${NC}"
    echo -e "${YELLOW}File permissions set to 600 (owner read/write only)${NC}"
fi

echo ""
echo -e "Full credentials are in: ${CYAN}$ENV_FILE${NC}"
echo ""
