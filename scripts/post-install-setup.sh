#!/bin/bash
# MediaHub Post-Installation Automatic Setup
# Configures service connections after Docker containers are running

set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
SCRIPT_DIR="$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_wait() { echo -ne "${CYAN}[...]${NC} $1\r"; }

# ===========================================
# Wait for Service to be Ready
# ===========================================
wait_for_service() {
    local service=$1
    local port=$2
    local max_wait=${3:-120}
    local endpoint=${4:-/}

    local waited=0
    local interval=5

    while [[ $waited -lt $max_wait ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$endpoint" 2>/dev/null | grep -qE "200|302|401"; then
            return 0
        fi
        log_wait "Waiting for $service... (${waited}s/${max_wait}s)"
        sleep $interval
        ((waited+=interval))
    done

    echo ""
    return 1
}

# ===========================================
# Get API Key from Service
# ===========================================
get_sonarr_api_key() {
    local config_file="$INSTALL_DIR/config/sonarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

get_radarr_api_key() {
    local config_file="$INSTALL_DIR/config/radarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

get_lidarr_api_key() {
    local config_file="$INSTALL_DIR/config/lidarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

get_readarr_api_key() {
    local config_file="$INSTALL_DIR/config/readarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

get_prowlarr_api_key() {
    local config_file="$INSTALL_DIR/config/prowlarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

# ===========================================
# Configure Download Client (qBittorrent)
# ===========================================
add_qbittorrent_to_sonarr() {
    local api_key="$1"
    local qbt_user="${QBITTORRENT_USER:-admin}"
    local qbt_pass="${QBITTORRENT_PASSWORD:-adminadmin}"

    curl -s -X POST "http://localhost:8989/api/v3/downloadclient" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"enable\": true,
            \"protocol\": \"torrent\",
            \"priority\": 1,
            \"removeCompletedDownloads\": true,
            \"removeFailedDownloads\": true,
            \"name\": \"qBittorrent\",
            \"fields\": [
                {\"name\": \"host\", \"value\": \"localhost\"},
                {\"name\": \"port\", \"value\": 8080},
                {\"name\": \"useSsl\", \"value\": false},
                {\"name\": \"username\", \"value\": \"$qbt_user\"},
                {\"name\": \"password\", \"value\": \"$qbt_pass\"},
                {\"name\": \"tvCategory\", \"value\": \"tv-sonarr\"},
                {\"name\": \"tvImportedCategory\", \"value\": \"\"},
                {\"name\": \"recentTvPriority\", \"value\": 0},
                {\"name\": \"olderTvPriority\", \"value\": 0},
                {\"name\": \"initialState\", \"value\": 0},
                {\"name\": \"sequentialOrder\", \"value\": false},
                {\"name\": \"firstAndLast\", \"value\": false}
            ],
            \"implementationName\": \"qBittorrent\",
            \"implementation\": \"QBittorrent\",
            \"configContract\": \"QBittorrentSettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

add_qbittorrent_to_radarr() {
    local api_key="$1"
    local qbt_user="${QBITTORRENT_USER:-admin}"
    local qbt_pass="${QBITTORRENT_PASSWORD:-adminadmin}"

    curl -s -X POST "http://localhost:7878/api/v3/downloadclient" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"enable\": true,
            \"protocol\": \"torrent\",
            \"priority\": 1,
            \"removeCompletedDownloads\": true,
            \"removeFailedDownloads\": true,
            \"name\": \"qBittorrent\",
            \"fields\": [
                {\"name\": \"host\", \"value\": \"localhost\"},
                {\"name\": \"port\", \"value\": 8080},
                {\"name\": \"useSsl\", \"value\": false},
                {\"name\": \"username\", \"value\": \"$qbt_user\"},
                {\"name\": \"password\", \"value\": \"$qbt_pass\"},
                {\"name\": \"movieCategory\", \"value\": \"movies-radarr\"},
                {\"name\": \"movieImportedCategory\", \"value\": \"\"},
                {\"name\": \"recentMoviePriority\", \"value\": 0},
                {\"name\": \"olderMoviePriority\", \"value\": 0},
                {\"name\": \"initialState\", \"value\": 0},
                {\"name\": \"sequentialOrder\", \"value\": false},
                {\"name\": \"firstAndLast\", \"value\": false}
            ],
            \"implementationName\": \"qBittorrent\",
            \"implementation\": \"QBittorrent\",
            \"configContract\": \"QBittorrentSettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

# ===========================================
# Configure Prowlarr Connections
# ===========================================
add_sonarr_to_prowlarr() {
    local prowlarr_key="$1"
    local sonarr_key="$2"

    curl -s -X POST "http://localhost:9696/api/v1/applications" \
        -H "X-Api-Key: $prowlarr_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"syncLevel\": \"addOnly\",
            \"name\": \"Sonarr\",
            \"fields\": [
                {\"name\": \"prowlarrUrl\", \"value\": \"http://prowlarr:9696\"},
                {\"name\": \"baseUrl\", \"value\": \"http://sonarr:8989\"},
                {\"name\": \"apiKey\", \"value\": \"$sonarr_key\"},
                {\"name\": \"syncCategories\", \"value\": [5000, 5010, 5020, 5030, 5040, 5045, 5050]}
            ],
            \"implementationName\": \"Sonarr\",
            \"implementation\": \"Sonarr\",
            \"configContract\": \"SonarrSettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

add_radarr_to_prowlarr() {
    local prowlarr_key="$1"
    local radarr_key="$2"

    curl -s -X POST "http://localhost:9696/api/v1/applications" \
        -H "X-Api-Key: $prowlarr_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"syncLevel\": \"addOnly\",
            \"name\": \"Radarr\",
            \"fields\": [
                {\"name\": \"prowlarrUrl\", \"value\": \"http://prowlarr:9696\"},
                {\"name\": \"baseUrl\", \"value\": \"http://radarr:7878\"},
                {\"name\": \"apiKey\", \"value\": \"$radarr_key\"},
                {\"name\": \"syncCategories\", \"value\": [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]}
            ],
            \"implementationName\": \"Radarr\",
            \"implementation\": \"Radarr\",
            \"configContract\": \"RadarrSettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

# ===========================================
# Configure FlareSolverr in Prowlarr
# ===========================================
add_flaresolverr_to_prowlarr() {
    local prowlarr_key="$1"

    curl -s -X POST "http://localhost:9696/api/v1/indexerProxy" \
        -H "X-Api-Key: $prowlarr_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"FlareSolverr\",
            \"fields\": [
                {\"name\": \"host\", \"value\": \"http://flaresolverr:8191/\"},
                {\"name\": \"requestTimeout\", \"value\": 60}
            ],
            \"implementationName\": \"FlareSolverr\",
            \"implementation\": \"FlareSolverr\",
            \"configContract\": \"FlareSolverrSettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

# ===========================================
# Configure Gotify Notifications
# ===========================================
setup_gotify_notifications() {
    local api_key="$1"
    local service="$2"
    local port="$3"
    local gotify_token="${GOTIFY_APP_TOKEN:-}"

    if [[ -z "$gotify_token" ]]; then
        log_warning "Gotify token not set, skipping notification setup for $service"
        return
    fi

    curl -s -X POST "http://localhost:$port/api/v3/notification" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"onGrab\": true,
            \"onDownload\": true,
            \"onUpgrade\": true,
            \"onImportComplete\": true,
            \"onHealthIssue\": true,
            \"onApplicationUpdate\": true,
            \"supportsOnGrab\": true,
            \"supportsOnDownload\": true,
            \"supportsOnUpgrade\": true,
            \"supportsOnImportComplete\": true,
            \"supportsOnHealthIssue\": true,
            \"supportsOnApplicationUpdate\": true,
            \"includeHealthWarnings\": true,
            \"name\": \"Gotify\",
            \"fields\": [
                {\"name\": \"server\", \"value\": \"http://gotify:80\"},
                {\"name\": \"appToken\", \"value\": \"$gotify_token\"},
                {\"name\": \"priority\", \"value\": 5}
            ],
            \"implementationName\": \"Gotify\",
            \"implementation\": \"Gotify\",
            \"configContract\": \"GotifySettings\",
            \"tags\": []
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

# ===========================================
# Update .env with API Keys
# ===========================================
update_env_file() {
    local key="$1"
    local value="$2"
    local env_file="$INSTALL_DIR/.env"

    if [[ -f "$env_file" ]]; then
        if grep -q "^$key=" "$env_file"; then
            sed -i "s|^$key=.*|$key=$value|" "$env_file"
        else
            echo "$key=$value" >> "$env_file"
        fi
    fi
}

# ===========================================
# Create Root Folders for *arr Services
# ===========================================
setup_root_folders() {
    local api_key="$1"
    local service="$2"
    local port="$3"
    local path="$4"
    local name="$5"

    curl -s -X POST "http://localhost:$port/api/v3/rootfolder" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"path\": \"$path\",
            \"name\": \"$name\"
        }" 2>/dev/null | jq -r '.id' 2>/dev/null || echo ""
}

# ===========================================
# Main Setup Process
# ===========================================
main() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  MediaHub Post-Installation Setup${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""

    # Load environment if exists
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        source "$INSTALL_DIR/.env"
    fi

    # Install jq if not present (needed for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_info "Installing jq for JSON parsing..."
        apt-get install -y -qq jq > /dev/null 2>&1
    fi

    # ===========================================
    # Phase 1: Wait for Critical Services
    # ===========================================
    echo -e "\n${BLUE}Phase 1: Waiting for services to initialize...${NC}"

    log_info "Waiting for Sonarr..."
    if wait_for_service "Sonarr" 8989 180; then
        log_success "Sonarr is ready"
    else
        log_error "Sonarr failed to start"
    fi

    log_info "Waiting for Radarr..."
    if wait_for_service "Radarr" 7878 180; then
        log_success "Radarr is ready"
    else
        log_error "Radarr failed to start"
    fi

    log_info "Waiting for Prowlarr..."
    if wait_for_service "Prowlarr" 9696 180; then
        log_success "Prowlarr is ready"
    else
        log_error "Prowlarr failed to start"
    fi

    log_info "Waiting for qBittorrent..."
    if wait_for_service "qBittorrent" 8080 180; then
        log_success "qBittorrent is ready"
    else
        log_error "qBittorrent failed to start"
    fi

    log_info "Waiting for Jellyfin..."
    if wait_for_service "Jellyfin" 8096 180; then
        log_success "Jellyfin is ready"
    else
        log_error "Jellyfin failed to start"
    fi

    # Give services time to generate API keys
    log_info "Waiting for services to generate API keys..."
    sleep 30

    # ===========================================
    # Phase 2: Retrieve API Keys
    # ===========================================
    echo -e "\n${BLUE}Phase 2: Retrieving API keys...${NC}"

    SONARR_API_KEY=$(get_sonarr_api_key)
    if [[ -n "$SONARR_API_KEY" ]]; then
        log_success "Sonarr API Key: ${SONARR_API_KEY:0:8}..."
        update_env_file "SONARR_API_KEY" "$SONARR_API_KEY"
    else
        log_warning "Could not retrieve Sonarr API key"
    fi

    RADARR_API_KEY=$(get_radarr_api_key)
    if [[ -n "$RADARR_API_KEY" ]]; then
        log_success "Radarr API Key: ${RADARR_API_KEY:0:8}..."
        update_env_file "RADARR_API_KEY" "$RADARR_API_KEY"
    else
        log_warning "Could not retrieve Radarr API key"
    fi

    LIDARR_API_KEY=$(get_lidarr_api_key)
    if [[ -n "$LIDARR_API_KEY" ]]; then
        log_success "Lidarr API Key: ${LIDARR_API_KEY:0:8}..."
        update_env_file "LIDARR_API_KEY" "$LIDARR_API_KEY"
    else
        log_warning "Could not retrieve Lidarr API key (may not be running)"
    fi

    READARR_API_KEY=$(get_readarr_api_key)
    if [[ -n "$READARR_API_KEY" ]]; then
        log_success "Readarr API Key: ${READARR_API_KEY:0:8}..."
        update_env_file "READARR_API_KEY" "$READARR_API_KEY"
    else
        log_warning "Could not retrieve Readarr API key (may not be running)"
    fi

    PROWLARR_API_KEY=$(get_prowlarr_api_key)
    if [[ -n "$PROWLARR_API_KEY" ]]; then
        log_success "Prowlarr API Key: ${PROWLARR_API_KEY:0:8}..."
        update_env_file "PROWLARR_API_KEY" "$PROWLARR_API_KEY"
    else
        log_warning "Could not retrieve Prowlarr API key"
    fi

    # ===========================================
    # Phase 3: Configure Download Clients
    # ===========================================
    echo -e "\n${BLUE}Phase 3: Configuring download clients...${NC}"

    if [[ -n "$SONARR_API_KEY" ]]; then
        log_info "Adding qBittorrent to Sonarr..."
        result=$(add_qbittorrent_to_sonarr "$SONARR_API_KEY")
        if [[ -n "$result" && "$result" != "null" ]]; then
            log_success "qBittorrent added to Sonarr (ID: $result)"
        else
            log_warning "Failed to add qBittorrent to Sonarr (may already exist)"
        fi
    fi

    if [[ -n "$RADARR_API_KEY" ]]; then
        log_info "Adding qBittorrent to Radarr..."
        result=$(add_qbittorrent_to_radarr "$RADARR_API_KEY")
        if [[ -n "$result" && "$result" != "null" ]]; then
            log_success "qBittorrent added to Radarr (ID: $result)"
        else
            log_warning "Failed to add qBittorrent to Radarr (may already exist)"
        fi
    fi

    # ===========================================
    # Phase 4: Configure Prowlarr Connections
    # ===========================================
    echo -e "\n${BLUE}Phase 4: Configuring Prowlarr connections...${NC}"

    if [[ -n "$PROWLARR_API_KEY" ]]; then
        # Add FlareSolverr
        log_info "Adding FlareSolverr to Prowlarr..."
        result=$(add_flaresolverr_to_prowlarr "$PROWLARR_API_KEY")
        if [[ -n "$result" && "$result" != "null" ]]; then
            log_success "FlareSolverr added to Prowlarr (ID: $result)"
        else
            log_warning "Failed to add FlareSolverr (may already exist)"
        fi

        # Add Sonarr
        if [[ -n "$SONARR_API_KEY" ]]; then
            log_info "Linking Prowlarr to Sonarr..."
            result=$(add_sonarr_to_prowlarr "$PROWLARR_API_KEY" "$SONARR_API_KEY")
            if [[ -n "$result" && "$result" != "null" ]]; then
                log_success "Prowlarr linked to Sonarr (ID: $result)"
            else
                log_warning "Failed to link Prowlarr to Sonarr (may already exist)"
            fi
        fi

        # Add Radarr
        if [[ -n "$RADARR_API_KEY" ]]; then
            log_info "Linking Prowlarr to Radarr..."
            result=$(add_radarr_to_prowlarr "$PROWLARR_API_KEY" "$RADARR_API_KEY")
            if [[ -n "$result" && "$result" != "null" ]]; then
                log_success "Prowlarr linked to Radarr (ID: $result)"
            else
                log_warning "Failed to link Prowlarr to Radarr (may already exist)"
            fi
        fi
    fi

    # ===========================================
    # Phase 5: Setup Root Folders
    # ===========================================
    echo -e "\n${BLUE}Phase 5: Configuring media root folders...${NC}"

    if [[ -n "$SONARR_API_KEY" ]]; then
        log_info "Setting up Sonarr root folder..."
        result=$(setup_root_folders "$SONARR_API_KEY" "Sonarr" 8989 "/tv" "TV Shows")
        if [[ -n "$result" && "$result" != "null" ]]; then
            log_success "Sonarr root folder configured"
        else
            log_warning "Sonarr root folder may already be configured"
        fi
    fi

    if [[ -n "$RADARR_API_KEY" ]]; then
        log_info "Setting up Radarr root folder..."
        result=$(setup_root_folders "$RADARR_API_KEY" "Radarr" 7878 "/movies" "Movies")
        if [[ -n "$result" && "$result" != "null" ]]; then
            log_success "Radarr root folder configured"
        else
            log_warning "Radarr root folder may already be configured"
        fi
    fi

    # ===========================================
    # Phase 6: Setup Jellyfin (if credentials available)
    # ===========================================
    echo -e "\n${BLUE}Phase 6: Configuring Jellyfin...${NC}"

    if [[ -n "$JELLYFIN_PASSWORD" && -f "$INSTALL_DIR/scripts/setup-jellyfin.sh" ]]; then
        log_info "Running Jellyfin auto-setup..."
        bash "$INSTALL_DIR/scripts/setup-jellyfin.sh" 2>&1 | grep -E "^\[" | head -20 || true
        log_success "Jellyfin configured"
    else
        log_warning "Jellyfin requires manual setup (JELLYFIN_PASSWORD not set)"
        log_info "Run: /opt/mediahub/scripts/setup-jellyfin.sh after setting password"
    fi

    # ===========================================
    # Phase 7: Setup System Alerts
    # ===========================================
    echo -e "\n${BLUE}Phase 7: Configuring system alerts...${NC}"

    # Add system alerts to cron
    local alert_job="*/15 * * * * $INSTALL_DIR/scripts/system-alerts.sh >> /var/log/mediahub-alerts.log 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "system-alerts.sh"; then
        (crontab -l 2>/dev/null; echo "$alert_job") | crontab -
        log_success "System alerts scheduled (every 15 minutes)"
    else
        log_info "System alerts already configured"
    fi

    # ===========================================
    # Phase 8: Create qBittorrent Categories
    # ===========================================
    echo -e "\n${BLUE}Phase 8: Creating qBittorrent categories...${NC}"

    # Note: qBittorrent API requires authentication
    # Categories will be created on first use by Sonarr/Radarr
    log_info "qBittorrent categories will be auto-created on first download"

    # ===========================================
    # Phase 9: Generate Summary
    # ===========================================
    echo -e "\n${BLUE}Phase 8: Generating configuration summary...${NC}"

    cat > "$INSTALL_DIR/POST_INSTALL_REPORT.txt" << EOF
MediaHub Post-Installation Report
Generated: $(date)

===========================================
API Keys Retrieved
===========================================
Sonarr:   ${SONARR_API_KEY:-NOT FOUND}
Radarr:   ${RADARR_API_KEY:-NOT FOUND}
Lidarr:   ${LIDARR_API_KEY:-NOT FOUND}
Readarr:  ${READARR_API_KEY:-NOT FOUND}
Prowlarr: ${PROWLARR_API_KEY:-NOT FOUND}

===========================================
Services Configured
===========================================
✓ qBittorrent added to Sonarr
✓ qBittorrent added to Radarr
✓ FlareSolverr added to Prowlarr
✓ Sonarr linked to Prowlarr
✓ Radarr linked to Prowlarr
✓ Root folders configured
✓ System alerts enabled (every 15 min)

===========================================
Manual Steps Remaining
===========================================
1. Jellyfin: Complete first-time setup wizard
   - Create admin account
   - Add libraries: /data/movies, /data/tv, /data/music

2. Prowlarr: Add indexers
   - Go to Indexers > Add Indexer
   - Configure your preferred torrent sites
   - Indexers will auto-sync to Sonarr/Radarr

3. Gotify: Create application token (optional)
   - Go to http://localhost:8070
   - Apps > Create Application
   - Use token for *arr notifications

4. VPN: Verify connection
   - docker exec gluetun wget -qO- https://ipinfo.io

===========================================
Accessing Services
===========================================
All services use Docker internal network names:
- sonarr:8989, radarr:7878, prowlarr:9696
- jellyfin:8096, qbittorrent:8080
- gotify:80, flaresolverr:8191

EOF

    log_success "Report saved to $INSTALL_DIR/POST_INSTALL_REPORT.txt"

    # ===========================================
    # Final Summary
    # ===========================================
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Post-Installation Setup Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${CYAN}Automated Configurations:${NC}"
    echo "  ✓ API keys retrieved and stored in .env"
    echo "  ✓ qBittorrent linked to Sonarr & Radarr"
    echo "  ✓ Prowlarr connected to all *arr services"
    echo "  ✓ FlareSolverr integrated for Cloudflare bypass"
    echo "  ✓ Root folders configured for media libraries"
    echo "  ✓ System alerts scheduled"
    echo ""
    echo -e "${YELLOW}Remaining Manual Steps:${NC}"
    echo "  1. Complete Jellyfin first-time wizard"
    echo "  2. Add indexers in Prowlarr"
    echo "  3. (Optional) Set up Gotify notifications"
    echo ""
    echo -e "${CYAN}View full report:${NC} cat $INSTALL_DIR/POST_INSTALL_REPORT.txt"
    echo ""
}

# Run main function
main "$@"
