#!/bin/bash
# MediaHub Prowlarr Indexer Setup
# Adds common public indexers to Prowlarr automatically

set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

PROWLARR_URL="http://localhost:9696"

# ===========================================
# Get Prowlarr API Key
# ===========================================
get_prowlarr_api_key() {
    local config_file="$INSTALL_DIR/config/prowlarr/config.xml"
    if [[ -f "$config_file" ]]; then
        grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo ""
    fi
}

# ===========================================
# Add Public Indexer
# ===========================================
add_indexer() {
    local api_key="$1"
    local name="$2"
    local implementation="$3"
    local config_contract="$4"

    log_info "Adding indexer: $name..."

    local result=$(curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"enable\": true,
            \"redirect\": false,
            \"name\": \"$name\",
            \"fields\": [],
            \"implementationName\": \"$name\",
            \"implementation\": \"$implementation\",
            \"configContract\": \"$config_contract\",
            \"tags\": [],
            \"appProfileId\": 1,
            \"priority\": 25
        }" 2>/dev/null | jq -r '.id' 2>/dev/null)

    if [[ -n "$result" && "$result" != "null" ]]; then
        log_success "$name added (ID: $result)"
        return 0
    else
        log_warning "$name may already exist or failed to add"
        return 1
    fi
}

# ===========================================
# Add 1337x (Popular torrent site)
# ===========================================
add_1337x() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "1337x",
            "fields": [
                {"name": "baseUrl", "value": "https://1337x.to"},
                {"name": "sortRequestedByUser", "value": "seeders"},
                {"name": "orderRequestedByUser", "value": "desc"}
            ],
            "implementationName": "1337x",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 25
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Add YTS (Movies)
# ===========================================
add_yts() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "YTS",
            "fields": [
                {"name": "baseUrl", "value": "https://yts.mx"}
            ],
            "implementationName": "YTS",
            "implementation": "Yts",
            "configContract": "YtsSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 20
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Add EZTV (TV Shows)
# ===========================================
add_eztv() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "EZTV",
            "fields": [
                {"name": "baseUrl", "value": "https://eztv.re"},
                {"name": "baseSettings.limitsUnit", "value": 0}
            ],
            "implementationName": "EZTV",
            "implementation": "Eztv",
            "configContract": "EztvSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 20
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Add Nyaa (Anime)
# ===========================================
add_nyaa() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "Nyaa.si",
            "fields": [
                {"name": "baseUrl", "value": "https://nyaa.si"}
            ],
            "implementationName": "Nyaa.si",
            "implementation": "Nyaasi",
            "configContract": "NyaaSiSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 25
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Add The Pirate Bay
# ===========================================
add_tpb() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "ThePirateBay",
            "fields": [
                {"name": "baseUrl", "value": "https://thepiratebay.org"}
            ],
            "implementationName": "The Pirate Bay",
            "implementation": "TorrentPotato",
            "configContract": "TorrentPotatoSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 30
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Add RARBG (via clone/mirror)
# ===========================================
add_rarbg() {
    local api_key="$1"

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" \
        -H "Content-Type: application/json" \
        -d '{
            "enable": true,
            "redirect": false,
            "name": "RARBGmirror",
            "fields": [
                {"name": "baseUrl", "value": "https://rargb.to"}
            ],
            "implementationName": "RARBG",
            "implementation": "Cardigann",
            "configContract": "CardigannSettings",
            "tags": [],
            "appProfileId": 1,
            "priority": 25
        }' 2>/dev/null | jq -r '.id' 2>/dev/null
}

# ===========================================
# Sync Indexers to Apps
# ===========================================
sync_to_apps() {
    local api_key="$1"

    log_info "Syncing indexers to Sonarr and Radarr..."

    curl -s -X POST "$PROWLARR_URL/api/v1/indexer/action/syncAll" \
        -H "X-Api-Key: $api_key" > /dev/null 2>&1

    log_success "Indexers synced to all connected applications"
}

# ===========================================
# Test Indexers
# ===========================================
test_indexers() {
    local api_key="$1"

    log_info "Testing indexer connectivity..."

    local indexers=$(curl -s "$PROWLARR_URL/api/v1/indexer" \
        -H "X-Api-Key: $api_key" 2>/dev/null | jq -r '.[].id' 2>/dev/null)

    local success=0
    local failed=0

    for id in $indexers; do
        local test_result=$(curl -s -X POST "$PROWLARR_URL/api/v1/indexer/test?indexerId=$id" \
            -H "X-Api-Key: $api_key" 2>/dev/null | jq -r '.isValid' 2>/dev/null)

        if [[ "$test_result" == "true" ]]; then
            ((success++))
        else
            ((failed++))
        fi
    done

    log_info "Test results: $success working, $failed failed"
}

# ===========================================
# Main Setup
# ===========================================
main() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Prowlarr Indexer Auto-Setup${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Install jq if needed
    if ! command -v jq &> /dev/null; then
        log_info "Installing jq..."
        apt-get install -y -qq jq > /dev/null 2>&1
    fi

    # Get API key
    local api_key=$(get_prowlarr_api_key)
    if [[ -z "$api_key" ]]; then
        log_error "Could not retrieve Prowlarr API key"
        echo "Make sure Prowlarr is running: docker ps | grep prowlarr"
        exit 1
    fi
    log_success "Prowlarr API Key: ${api_key:0:8}..."

    # Check connectivity
    if ! curl -s "$PROWLARR_URL/api/v1/health" -H "X-Api-Key: $api_key" > /dev/null 2>&1; then
        log_error "Cannot connect to Prowlarr API"
        exit 1
    fi

    echo ""
    echo "Select indexers to add:"
    echo "  1) Standard Pack (YTS, EZTV, 1337x) - Recommended"
    echo "  2) Full Pack (+ Nyaa for anime)"
    echo "  3) Custom selection"
    echo ""
    read -p "Choice [1]: " choice
    choice=${choice:-1}

    local added=0

    case $choice in
        1)
            # Standard pack
            log_info "Installing Standard Indexer Pack..."
            echo ""

            result=$(add_yts "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "YTS (Movies) - ID: $result"

            result=$(add_eztv "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "EZTV (TV Shows) - ID: $result"

            result=$(add_1337x "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "1337x (General) - ID: $result"
            ;;

        2)
            # Full pack
            log_info "Installing Full Indexer Pack..."
            echo ""

            result=$(add_yts "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "YTS (Movies) - ID: $result"

            result=$(add_eztv "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "EZTV (TV Shows) - ID: $result"

            result=$(add_1337x "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "1337x (General) - ID: $result"

            result=$(add_nyaa "$api_key")
            [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "Nyaa.si (Anime) - ID: $result"
            ;;

        3)
            # Custom selection
            echo ""
            echo "Available indexers:"
            echo "  y) YTS - Movies (recommended)"
            echo "  e) EZTV - TV Shows (recommended)"
            echo "  1) 1337x - General torrents"
            echo "  n) Nyaa.si - Anime"
            echo "  t) ThePirateBay - General"
            echo ""
            read -p "Enter letters of indexers to add (e.g., ye1): " selection

            for (( i=0; i<${#selection}; i++ )); do
                case ${selection:$i:1} in
                    y)
                        result=$(add_yts "$api_key")
                        [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "YTS added"
                        ;;
                    e)
                        result=$(add_eztv "$api_key")
                        [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "EZTV added"
                        ;;
                    1)
                        result=$(add_1337x "$api_key")
                        [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "1337x added"
                        ;;
                    n)
                        result=$(add_nyaa "$api_key")
                        [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "Nyaa.si added"
                        ;;
                    t)
                        result=$(add_tpb "$api_key")
                        [[ -n "$result" && "$result" != "null" ]] && ((added++)) && log_success "ThePirateBay added"
                        ;;
                esac
            done
            ;;
    esac

    echo ""
    log_info "Added $added indexers"

    # Sync to apps
    echo ""
    sync_to_apps "$api_key"

    # Summary
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Indexer Setup Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Indexers added: $added"
    echo ""
    echo "Your indexers are now synced to Sonarr and Radarr!"
    echo "You can search for content directly from those apps."
    echo ""
    echo "To add more indexers:"
    echo "  - Go to http://localhost:9696"
    echo "  - Indexers > Add Indexer"
    echo "  - Search for your preferred sites"
    echo ""
    echo -e "${YELLOW}Note:${NC} Some indexers may require FlareSolverr for Cloudflare"
    echo "bypass. This is already configured in Prowlarr."
    echo ""
}

main "$@"
