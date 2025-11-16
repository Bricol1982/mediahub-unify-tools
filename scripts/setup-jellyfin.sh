#!/bin/bash
# MediaHub Jellyfin Automatic Setup
# Configures Jellyfin with admin user and media libraries

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

JELLYFIN_URL="http://localhost:8096"

# ===========================================
# Wait for Jellyfin
# ===========================================
wait_for_jellyfin() {
    local max_wait=180
    local waited=0

    log_info "Waiting for Jellyfin to be ready..."
    while [[ $waited -lt $max_wait ]]; do
        if curl -s "$JELLYFIN_URL/System/Info/Public" 2>/dev/null | grep -q "ServerName"; then
            return 0
        fi
        sleep 5
        ((waited+=5))
    done
    return 1
}

# ===========================================
# Check if Setup is Required
# ===========================================
check_setup_required() {
    local status=$(curl -s "$JELLYFIN_URL/Startup/Configuration" 2>/dev/null)
    if echo "$status" | grep -q "IsStartupWizardCompleted.*false"; then
        return 0  # Setup required
    fi
    return 1  # Already configured
}

# ===========================================
# Complete Startup Wizard
# ===========================================
complete_startup_wizard() {
    local admin_user="$1"
    local admin_pass="$2"
    local preferred_lang="${3:-fr}"

    log_info "Starting Jellyfin setup wizard..."

    # Step 1: Set preferred metadata language
    log_info "Setting metadata language..."
    curl -s -X POST "$JELLYFIN_URL/Startup/Configuration" \
        -H "Content-Type: application/json" \
        -d "{
            \"UICulture\": \"$preferred_lang\",
            \"MetadataCountryCode\": \"FR\",
            \"PreferredMetadataLanguage\": \"$preferred_lang\"
        }" > /dev/null

    # Step 2: Create admin user
    log_info "Creating admin user: $admin_user"
    curl -s -X POST "$JELLYFIN_URL/Startup/User" \
        -H "Content-Type: application/json" \
        -d "{
            \"Name\": \"$admin_user\",
            \"Password\": \"$admin_pass\"
        }" > /dev/null

    # Step 3: Set remote access configuration
    log_info "Configuring remote access..."
    curl -s -X POST "$JELLYFIN_URL/Startup/RemoteAccess" \
        -H "Content-Type: application/json" \
        -d "{
            \"EnableRemoteAccess\": true,
            \"EnableAutomaticPortMapping\": false
        }" > /dev/null

    # Step 4: Complete the wizard
    log_info "Completing setup wizard..."
    curl -s -X POST "$JELLYFIN_URL/Startup/Complete" \
        -H "Content-Type: application/json" > /dev/null

    log_success "Jellyfin setup wizard completed"
}

# ===========================================
# Authenticate and Get Token
# ===========================================
get_auth_token() {
    local username="$1"
    local password="$2"

    local response=$(curl -s -X POST "$JELLYFIN_URL/Users/AuthenticateByName" \
        -H "Content-Type: application/json" \
        -H "X-Emby-Authorization: MediaBrowser Client=\"MediaHub\", Device=\"Server\", DeviceId=\"mediahub-setup\", Version=\"1.0.0\"" \
        -d "{
            \"Username\": \"$username\",
            \"Pw\": \"$password\"
        }" 2>/dev/null)

    echo "$response" | jq -r '.AccessToken' 2>/dev/null
}

# ===========================================
# Add Media Library
# ===========================================
add_library() {
    local token="$1"
    local user_id="$2"
    local name="$3"
    local type="$4"
    local path="$5"

    log_info "Adding library: $name ($type)"

    local collection_type=""
    case $type in
        "movies")
            collection_type="movies"
            ;;
        "tvshows")
            collection_type="tvshows"
            ;;
        "music")
            collection_type="music"
            ;;
        "books")
            collection_type="books"
            ;;
        "photos")
            collection_type="homevideos"
            ;;
    esac

    curl -s -X POST "$JELLYFIN_URL/Library/VirtualFolders?collectionType=$collection_type&refreshLibrary=false&name=$name" \
        -H "X-Emby-Token: $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"LibraryOptions\": {
                \"EnablePhotos\": true,
                \"EnableRealtimeMonitor\": true,
                \"EnableChapterImageExtraction\": false,
                \"ExtractChapterImagesDuringLibraryScan\": false,
                \"PathInfos\": [
                    {
                        \"Path\": \"$path\"
                    }
                ],
                \"SaveLocalMetadata\": true,
                \"EnableInternetProviders\": true,
                \"EnableAutomaticSeriesGrouping\": true,
                \"EnableEmbeddedTitles\": false,
                \"EnableEmbeddedEpisodeInfos\": false,
                \"AutomaticRefreshIntervalDays\": 0,
                \"PreferredMetadataLanguage\": \"fr\",
                \"MetadataCountryCode\": \"FR\",
                \"SeasonZeroDisplayName\": \"Specials\",
                \"MetadataSavers\": [],
                \"DisabledLocalMetadataReaders\": [],
                \"LocalMetadataReaderOrder\": [\"Nfo\"],
                \"DisabledSubtitleFetchers\": [],
                \"SubtitleFetcherOrder\": [],
                \"SkipSubtitlesIfEmbeddedSubtitlesPresent\": false,
                \"SkipSubtitlesIfAudioTrackMatches\": false,
                \"SubtitleDownloadLanguages\": [\"fre\"],
                \"RequirePerfectSubtitleMatch\": true,
                \"SaveSubtitlesWithMedia\": true,
                \"AutomaticallyAddToCollection\": false,
                \"AllowEmbeddedSubtitles\": \"AllowAll\",
                \"TypeOptions\": []
            }
        }" > /dev/null 2>&1

    log_success "Library '$name' added"
}

# ===========================================
# Get User ID
# ===========================================
get_user_id() {
    local token="$1"
    local username="$2"

    curl -s "$JELLYFIN_URL/Users" \
        -H "X-Emby-Token: $token" 2>/dev/null | \
        jq -r ".[] | select(.Name==\"$username\") | .Id" 2>/dev/null
}

# ===========================================
# Configure Transcoding (for RPi)
# ===========================================
configure_transcoding() {
    local token="$1"

    log_info "Configuring transcoding for Raspberry Pi..."

    # Get current config
    local config=$(curl -s "$JELLYFIN_URL/System/Configuration/encoding" \
        -H "X-Emby-Token: $token" 2>/dev/null)

    # Update for Raspberry Pi (V4L2 hardware encoding)
    curl -s -X POST "$JELLYFIN_URL/System/Configuration/encoding" \
        -H "X-Emby-Token: $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"EncodingThreadCount\": -1,
            \"TranscodingTempPath\": \"/config/transcodes\",
            \"FallbackFontPath\": \"\",
            \"EnableFallbackFont\": false,
            \"DownMixAudioBoost\": 2,
            \"MaxMuxingQueueSize\": 2048,
            \"EnableThrottling\": true,
            \"ThrottleDelaySeconds\": 180,
            \"HardwareAccelerationType\": \"v4l2m2m\",
            \"EncoderAppPath\": \"/usr/lib/jellyfin-ffmpeg/ffmpeg\",
            \"EncoderAppPathDisplay\": \"/usr/lib/jellyfin-ffmpeg/ffmpeg\",
            \"VaapiDevice\": \"/dev/dri/renderD128\",
            \"EnableTonemapping\": false,
            \"EnableVppTonemapping\": false,
            \"TonemappingAlgorithm\": \"hable\",
            \"TonemappingRange\": \"auto\",
            \"TonemappingDesat\": 0,
            \"TonemappingThreshold\": 0.8,
            \"TonemappingPeak\": 100,
            \"TonemappingParam\": 0,
            \"VppTonemappingBrightness\": 0,
            \"VppTonemappingContrast\": 1.2,
            \"H264Crf\": 23,
            \"H265Crf\": 28,
            \"EncoderPreset\": \"fast\",
            \"DeinterlaceDoubleRate\": false,
            \"DeinterlaceMethod\": \"yadif\",
            \"EnableDecodingColorDepth10Hevc\": true,
            \"EnableDecodingColorDepth10Vp9\": true,
            \"EnableEnhancedNvdecDecoder\": false,
            \"PreferSystemNativeHwDecoder\": true,
            \"EnableIntelLowPowerH264HwEncoder\": false,
            \"EnableIntelLowPowerHevcHwEncoder\": false,
            \"EnableHardwareEncoding\": true,
            \"AllowHevcEncoding\": false,
            \"EnableSubtitleExtraction\": true,
            \"HardwareDecodingCodecs\": [\"h264\", \"vc1\", \"mpeg2video\", \"mpeg4\", \"vp8\", \"vp9\"],
            \"AllowOnDemandMetadataBasedKeyframeExtractionForExtensions\": [\"mkv\"]
        }" > /dev/null 2>&1

    log_success "Transcoding configured for Raspberry Pi"
}

# ===========================================
# Main Setup
# ===========================================
main() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  Jellyfin Automatic Setup${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""

    # Load environment
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        source "$INSTALL_DIR/.env"
    fi

    # Get credentials
    local admin_user="${JELLYFIN_USER:-admin}"
    local admin_pass="${JELLYFIN_PASSWORD:-}"

    if [[ -z "$admin_pass" ]]; then
        log_error "JELLYFIN_PASSWORD not set in .env"
        echo "Please run with: JELLYFIN_PASSWORD=your_password $0"
        exit 1
    fi

    # Install jq if needed
    if ! command -v jq &> /dev/null; then
        log_info "Installing jq..."
        apt-get install -y -qq jq > /dev/null 2>&1
    fi

    # Wait for Jellyfin
    if ! wait_for_jellyfin; then
        log_error "Jellyfin is not responding"
        exit 1
    fi
    log_success "Jellyfin is running"

    # Check if setup is needed
    if ! check_setup_required; then
        log_warning "Jellyfin is already configured"
        echo ""

        # Still try to get token for additional setup
        log_info "Authenticating to add libraries..."
        local token=$(get_auth_token "$admin_user" "$admin_pass")
        if [[ -z "$token" || "$token" == "null" ]]; then
            log_error "Failed to authenticate. Check credentials."
            exit 1
        fi
    else
        # Complete wizard
        complete_startup_wizard "$admin_user" "$admin_pass" "fr"

        # Get auth token
        log_info "Authenticating..."
        sleep 5  # Wait for user creation

        local token=$(get_auth_token "$admin_user" "$admin_pass")
        if [[ -z "$token" || "$token" == "null" ]]; then
            log_error "Failed to authenticate after setup"
            exit 1
        fi
    fi

    log_success "Authenticated successfully"

    # Get user ID
    local user_id=$(get_user_id "$token" "$admin_user")
    log_info "User ID: $user_id"

    # Add libraries
    echo ""
    log_info "Adding media libraries..."

    # Movies
    if [[ -d "/mnt/media/library/movies" ]] || [[ -d "$MEDIA_PATH/movies" ]]; then
        add_library "$token" "$user_id" "Films" "movies" "/data/movies"
    fi

    # TV Shows
    if [[ -d "/mnt/media/library/tv" ]] || [[ -d "$MEDIA_PATH/tv" ]]; then
        add_library "$token" "$user_id" "Séries TV" "tvshows" "/data/tv"
    fi

    # Music
    if [[ -d "/mnt/media/library/music" ]] || [[ -d "$MEDIA_PATH/music" ]]; then
        add_library "$token" "$user_id" "Musique" "music" "/data/music"
    fi

    # Photos (optional)
    if [[ -d "/mnt/media/library/photos" ]] || [[ -d "$MEDIA_PATH/photos" ]]; then
        add_library "$token" "$user_id" "Photos" "photos" "/data/photos"
    fi

    # Configure for RPi
    echo ""
    configure_transcoding "$token"

    # Trigger library scan
    echo ""
    log_info "Starting initial library scan..."
    curl -s -X POST "$JELLYFIN_URL/Library/Refresh" \
        -H "X-Emby-Token: $token" > /dev/null 2>&1
    log_success "Library scan initiated (runs in background)"

    # Save API key
    local api_key=$(curl -s "$JELLYFIN_URL/Auth/Keys" \
        -H "X-Emby-Token: $token" 2>/dev/null | jq -r '.[0].AccessToken' 2>/dev/null)

    if [[ -n "$api_key" && "$api_key" != "null" ]]; then
        log_info "Jellyfin API Key: ${api_key:0:8}..."

        # Update .env
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            if grep -q "^JELLYFIN_API_KEY=" "$INSTALL_DIR/.env"; then
                sed -i "s|^JELLYFIN_API_KEY=.*|JELLYFIN_API_KEY=$api_key|" "$INSTALL_DIR/.env"
            else
                echo "JELLYFIN_API_KEY=$api_key" >> "$INSTALL_DIR/.env"
            fi
        fi
    fi

    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Jellyfin Setup Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "Admin User: $admin_user"
    echo "Access at: http://$(hostname -I | awk '{print $1}'):8096"
    echo ""
    echo "Libraries added:"
    echo "  - Films (/data/movies)"
    echo "  - Séries TV (/data/tv)"
    echo "  - Musique (/data/music)"
    echo ""
    echo "Transcoding: Configured for Raspberry Pi (V4L2)"
    echo "Library scan: Running in background"
    echo ""
}

main "$@"
