#!/bin/bash
# MediaHub Installation Wizard - VERBOSE MODE
# Shows all installation steps in real-time with full output
# Use this for debugging or to see exactly what's happening

set -e

INSTALL_DIR="/opt/mediahub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/mediahub-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# State file for tracking
STATE_FILE="/tmp/mediahub_state"

# Language support
MEDIAHUB_LANG="${MEDIAHUB_LANG:-fr}"
declare -gA TRANSLATIONS

# ===========================================
# Verbose Output Functions
# ===========================================
phase() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    log "PHASE: $1"
}

step() {
    echo -e "${BLUE}→ $1${NC}"
    log "STEP: $1"
}

substep() {
    echo -e "  ${MAGENTA}• $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

info() {
    echo -e "${NC}  $1${NC}"
}

save_state() {
    echo "$1" > "$STATE_FILE"
    log "STATE: $1"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ===========================================
# Load Language Support
# ===========================================
load_i18n() {
    local lang_file="$SCRIPT_DIR/i18n/${MEDIAHUB_LANG}.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    elif [[ -f "$SCRIPT_DIR/i18n/fr.sh" ]]; then
        source "$SCRIPT_DIR/i18n/fr.sh"
    fi
}

t() {
    local key="$1"
    if [[ -n "${TRANSLATIONS[$key]}" ]]; then
        echo "${TRANSLATIONS[$key]}"
    else
        echo "$key"
    fi
}

# ===========================================
# Check for whiptail or dialog
# ===========================================
check_tui_tool() {
    if command -v whiptail &> /dev/null; then
        TUI="whiptail"
    elif command -v dialog &> /dev/null; then
        TUI="dialog"
    else
        step "Installing user interface (whiptail)..."
        apt-get update > /dev/null 2>&1
        apt-get install -y whiptail > /dev/null 2>&1
        TUI="whiptail"
        success "whiptail installed"
    fi
}

# ===========================================
# Language Selection
# ===========================================
select_language() {
    MEDIAHUB_LANG=$($TUI --title "Language / Langue / Idioma" \
        --menu "\nSelect your language:\nChoisissez votre langue:\nSeleccione su idioma:\n" 16 60 4 \
        "fr" "Francais (French)" \
        "en" "English" \
        "es" "Espanol (Spanish)" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$MEDIAHUB_LANG" ]]; then
        MEDIAHUB_LANG="fr"
    fi

    echo "MEDIAHUB_LANG=$MEDIAHUB_LANG" > "${HOME}/.mediahub_lang"
    export MEDIAHUB_LANG
    load_i18n
    return 0
}

# ===========================================
# Hardware Detection
# ===========================================
HARDWARE_MODE="full"

detect_hardware() {
    phase "HARDWARE DETECTION"

    step "Detecting system model..."
    local model=""
    if [[ -f /proc/device-tree/model ]]; then
        model=$(cat /proc/device-tree/model | tr -d '\0')
        success "Model: $model"
    elif [[ -f /sys/firmware/devicetree/base/model ]]; then
        model=$(cat /sys/firmware/devicetree/base/model | tr -d '\0')
        success "Model: $model"
    else
        warning "Could not detect model"
    fi

    step "Checking RAM..."
    local ram_mb=0
    if [[ -f /proc/meminfo ]]; then
        ram_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
        local ram_gb=$((ram_mb / 1024))
        success "RAM: ${ram_mb}MB (${ram_gb}GB)"
    fi

    step "Determining installation mode..."
    if [[ $ram_mb -lt 2000 ]]; then
        HARDWARE_MODE="limited"
        warning "Limited mode recommended (Pi3 compatible)"
        info "Services will be limited to conserve memory"
    else
        HARDWARE_MODE="full"
        success "Full mode supported"
        info "All services will be available"
    fi

    step "Checking external storage..."
    local disks=$(lsblk -d -o NAME,SIZE,MODEL,TRAN 2>/dev/null | grep -E "usb|sata" | grep -v "boot" || true)
    if [[ -n "$disks" ]]; then
        success "External storage detected:"
        echo "$disks" | while read -r line; do
            info "  $line"
        done
    else
        warning "No external USB/SATA storage detected"
    fi

    echo "$model|$ram_mb"
}

select_hardware_mode() {
    local hw_info
    hw_info=$(detect_hardware)
    local model=$(echo "$hw_info" | cut -d'|' -f1)
    local ram_mb=$(echo "$hw_info" | cut -d'|' -f2)

    local mode_default="full"
    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        mode_default="limited"
    fi

    HARDWARE_MODE=$($TUI --title "Mode d'Installation" \
        --menu "Detected: $model (${ram_mb}MB RAM)\n\nSelect installation mode:" 20 75 2 \
        "full" "Raspberry Pi 4 (4GB+) - All services (37+)" \
        "limited" "Raspberry Pi 3 (1GB) - Essential services (8)" \
        --default-item "$mode_default" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$HARDWARE_MODE" ]]; then
        HARDWARE_MODE="$mode_default"
    fi

    echo "HARDWARE_MODE=$HARDWARE_MODE" > "${HOME}/.mediahub_mode"
    export HARDWARE_MODE

    success "Hardware mode: $HARDWARE_MODE"
    return 0
}

# ===========================================
# TUI Helper Functions (same as original)
# ===========================================
show_welcome() {
    $TUI --title "$(t "installer.title")" \
        --msgbox "$(t "installer.welcome")\n\n$(t "installer.welcome_desc")\n\n$(t "common.continue")..." 22 70
}

show_requirements() {
    $TUI --title "$(t "installer.requirements")" \
        --yesno "$(t "installer.requirements_desc")" 20 60
    return $?
}

get_vpn_provider() {
    VPN_SERVICE_PROVIDER=$($TUI --title "$(t "vpn.title")" \
        --menu "$(t "vpn.select_provider")\n\n$(t "vpn.providers_info")" 22 70 12 \
        "SKIP" ">>> Configure VPN LATER <<<" \
        "protonvpn" "ProtonVPN (Recommended)" \
        "mullvad" "Mullvad (Anonymous)" \
        "nordvpn" "NordVPN (5000+ servers)" \
        "surfshark" "Surfshark (Unlimited)" \
        "pia" "Private Internet Access" \
        "expressvpn" "ExpressVPN (Fast)" \
        "ivpn" "IVPN (Open-source)" \
        "windscribe" "Windscribe" \
        "cyberghost" "CyberGhost" \
        "custom" "Custom Configuration" \
        3>&1 1>&2 2>&3)

    [[ -z "$VPN_SERVICE_PROVIDER" ]] && return 1
    return 0
}

skip_vpn_setup() {
    VPN_SERVICE_PROVIDER="none"
    VPN_TYPE="none"
    OPENVPN_USER=""
    OPENVPN_PASS=""
    WIREGUARD_PRIVATE_KEY=""
    WIREGUARD_ADDRESSES=""
    SERVER_COUNTRIES=""
    SERVER_REGIONS=""
    SERVER_CITIES=""

    $TUI --title "VPN Configuration Skipped" \
        --msgbox "VPN will NOT be configured now.\n\n\
You can configure it later by running:\n\
  $INSTALL_DIR/scripts/setup-vpn.sh\n\n\
WARNING: Without VPN, your downloads will NOT be protected!\n\n\
Services will still be installed but qBittorrent will be exposed." 16 70

    return 0
}

get_vpn_credentials() {
    if ! get_vpn_provider; then
        return 1
    fi

    case "$VPN_SERVICE_PROVIDER" in
        SKIP)
            skip_vpn_setup
            return $?
            ;;
        mullvad)
            get_wireguard_credentials
            return $?
            ;;
        custom)
            get_custom_vpn_config
            return $?
            ;;
        *)
            get_openvpn_credentials
            return $?
            ;;
    esac
}

get_openvpn_credentials() {
    local provider_name="$VPN_SERVICE_PROVIDER"
    local help_url="Check provider documentation"

    case "$VPN_SERVICE_PROVIDER" in
        protonvpn) provider_name="ProtonVPN"; help_url="account.protonvpn.com/account#openvpn" ;;
        nordvpn) provider_name="NordVPN"; help_url="my.nordaccount.com > Services > NordVPN" ;;
        surfshark) provider_name="Surfshark"; help_url="my.surfshark.com > VPN > Manual setup" ;;
        expressvpn) provider_name="ExpressVPN"; help_url="expressvpn.com/setup" ;;
        pia) provider_name="Private Internet Access"; help_url="privateinternetaccess.com/account" ;;
    esac

    local username=$($TUI --title "Configuration $provider_name (1/3)" \
        --inputbox "$(t "vpn.username") OpenVPN $provider_name:\n\n$(t "vpn.credentials_warning")\n\n$help_url\n\n$(t "vpn.credentials_help")" 18 70 3>&1 1>&2 2>&3)

    [[ -z "$username" ]] && return 1
    [[ ${#username} -lt 5 ]] && return 1

    local password=$($TUI --title "Configuration $provider_name (2/3)" \
        --passwordbox "$(t "vpn.password") OpenVPN $provider_name:" 12 70 3>&1 1>&2 2>&3)

    [[ -z "$password" ]] && return 1
    [[ ${#password} -lt 5 ]] && return 1

    local server_location
    if [[ "$VPN_SERVICE_PROVIDER" == "pia" ]]; then
        server_location=$($TUI --title "Configuration $provider_name (3/3)" \
            --inputbox "$(t "vpn.server_region"):\n\nExamples: Netherlands, Switzerland, Sweden" 12 70 "Netherlands" 3>&1 1>&2 2>&3)
        SERVER_REGIONS="$server_location"
        SERVER_COUNTRIES=""
    else
        server_location=$($TUI --title "Configuration $provider_name (3/3)" \
            --inputbox "$(t "vpn.server_country"):\n\nExamples: Netherlands, Switzerland, Sweden" 12 70 "Netherlands" 3>&1 1>&2 2>&3)
        SERVER_COUNTRIES="$server_location"
        SERVER_REGIONS=""
    fi

    OPENVPN_USER="$username"
    OPENVPN_PASS="$password"
    VPN_TYPE="openvpn"
    return 0
}

get_wireguard_credentials() {
    WIREGUARD_PRIVATE_KEY=$($TUI --title "Mullvad - Private Key (1/3)" \
        --inputbox "Enter your Wireguard private key:" 12 70 3>&1 1>&2 2>&3)
    [[ -z "$WIREGUARD_PRIVATE_KEY" ]] && return 1

    WIREGUARD_ADDRESSES=$($TUI --title "Mullvad - Addresses (2/3)" \
        --inputbox "Enter your Wireguard addresses:\n\nExample: 10.64.0.1/32" 12 70 3>&1 1>&2 2>&3)
    [[ -z "$WIREGUARD_ADDRESSES" ]] && return 1

    SERVER_CITIES=$($TUI --title "Mullvad - City (3/3)" \
        --inputbox "Server city (optional):\n\nExamples: amsterdam, zurich, stockholm" 14 70 3>&1 1>&2 2>&3)

    VPN_TYPE="wireguard"
    OPENVPN_USER=""
    OPENVPN_PASS=""
    return 0
}

get_custom_vpn_config() {
    VPN_TYPE=$($TUI --title "Custom VPN Config Type" \
        --menu "Select configuration type:" 12 60 2 \
        "openvpn" "OpenVPN (.ovpn file)" \
        "wireguard" "Wireguard (.conf file)" \
        3>&1 1>&2 2>&3)
    [[ -z "$VPN_TYPE" ]] && return 1
    return 0
}

get_master_password() {
    local pass1 pass2

    while true; do
        pass1=$($TUI --title "$(t "password.title")" \
            --passwordbox "$(t "password.desc")\n\n$(t "password.enter")" 20 65 3>&1 1>&2 2>&3)
        [[ -z "$pass1" ]] && return 1
        [[ ${#pass1} -lt 8 ]] && continue

        pass2=$($TUI --title "$(t "common.confirm")" \
            --passwordbox "$(t "password.confirm")" 10 50 3>&1 1>&2 2>&3)
        [[ "$pass1" != "$pass2" ]] && continue

        MASTER_PASSWORD="$pass1"
        return 0
    done
}

select_hdd() {
    local drives=$(lsblk -d -o NAME,SIZE,MODEL -n 2>/dev/null | grep -E "^sd" | awk '{print $1 " " $2 "-" $3}')

    if [[ -z "$drives" ]]; then
        USE_EXTERNAL_HDD=false
        return 0
    fi

    local options=()
    while IFS= read -r line; do
        local dev=$(echo "$line" | awk '{print $1}')
        local info=$(echo "$line" | awk '{print $2}')
        options+=("$dev" "$info")
    done <<< "$drives"

    local selected=$($TUI --title "Select Disk" \
        --menu "Select disk for media storage:\n\nWARNING: Will be formatted!" 18 70 5 \
        "${options[@]}" \
        "SKIP" "Don't use external disk" 3>&1 1>&2 2>&3)

    if [[ "$selected" == "SKIP" ]] || [[ -z "$selected" ]]; then
        USE_EXTERNAL_HDD=false
    else
        SELECTED_DRIVE="/dev/$selected"
        USE_EXTERNAL_HDD=true
    fi
    return 0
}

select_features() {
    FEATURES=$($TUI --title "$(t "features.title")" \
        --checklist "$(t "features.desc")" 20 70 10 \
        "TV_KIOSK" "$(t "features.tv_kiosk")" ON \
        "HDMI_CEC" "$(t "features.hdmi_cec")" ON \
        "NOTIFICATIONS" "$(t "features.notifications")" ON \
        "MONITORING" "$(t "features.monitoring")" ON \
        "AUTO_BACKUP" "Auto backups" ON \
        "ANIME" "Anime support" OFF \
        "COMICS" "Comics/Manga (Komga)" ON \
        "MUSIC" "Music server (Navidrome)" ON \
        3>&1 1>&2 2>&3)
    return 0
}

show_summary() {
    local summary="Installation Summary:\n\n"
    summary+="VPN Provider: $VPN_SERVICE_PROVIDER\n"
    summary+="Hardware Mode: $HARDWARE_MODE\n"
    summary+="Master Password: Set\n"
    [[ "$USE_EXTERNAL_HDD" == true ]] && summary+="External HDD: $SELECTED_DRIVE\n" || summary+="External HDD: None\n"
    summary+="\nFeatures: $FEATURES\n\n"
    summary+="Continue with installation?"

    $TUI --title "$(t "common.confirm")" --yesno "$summary" 28 60
    return $?
}

# ===========================================
# VERBOSE INSTALLATION (Main Difference)
# ===========================================
run_installation() {
    save_state "STARTING"

    phase "STARTING MEDIAUHB INSTALLATION"
    echo -e "${BOLD}Installation started at $(date)${NC}"
    echo ""

    # ========== SYSTEM UPDATE ==========
    phase "SYSTEM UPDATE"
    save_state "UPDATE"

    step "Updating package lists..."
    apt-get update 2>&1 | grep -E "^(Get:|Hit:|Ign:|Err:)" | head -20
    success "Package lists updated"

    step "Upgrading system packages..."
    info "This may take several minutes..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>&1 | grep -E "^(Reading|Building|Unpacking|Setting up)" | head -30
    success "System packages upgraded"

    # ========== DEPENDENCIES ==========
    phase "INSTALLING DEPENDENCIES"
    save_state "DEPS"

    step "Installing base packages..."
    local packages="curl wget git jq openssl gnupg2 ca-certificates lsb-release"
    for pkg in $packages; do
        substep "Installing $pkg..."
        apt-get install -y -qq "$pkg" 2>&1 | head -5 || true
    done
    success "Base packages installed"

    # ========== DOCKER ==========
    phase "DOCKER INSTALLATION"
    save_state "DOCKER_INSTALL"

    if command -v docker &> /dev/null; then
        success "Docker already installed"
        docker --version
    else
        step "Downloading Docker installation script..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        success "Script downloaded"

        step "Running Docker installer (this takes 2-5 minutes)..."
        info "Installing Docker CE for $(uname -m) architecture..."
        sh /tmp/get-docker.sh 2>&1 | grep -E "^(#|Executing|Adding|Created)" | head -30
        rm -f /tmp/get-docker.sh

        if command -v docker &> /dev/null; then
            success "Docker installed successfully"
            docker --version
        else
            error "Docker installation failed!"
            exit 1
        fi
    fi

    step "Enabling Docker service..."
    systemctl enable docker 2>&1 | head -5
    success "Docker enabled"

    step "Starting Docker service..."
    systemctl start docker 2>&1 | head -5
    success "Docker started"

    step "Adding user to docker group..."
    usermod -aG docker "${SUDO_USER:-pi}" 2>/dev/null || true
    success "User ${SUDO_USER:-pi} added to docker group"

    step "Checking docker-compose plugin..."
    if docker compose version &> /dev/null; then
        success "Docker Compose plugin available"
        docker compose version
    else
        step "Installing docker-compose-plugin..."
        apt-get install -y -qq docker-compose-plugin 2>&1 | head -10
        success "Docker Compose plugin installed"
    fi

    # ========== EXTERNAL HDD (BEFORE DOCKER CONFIG) ==========
    phase "EXTERNAL HDD SETUP"
    save_state "HDD_FORMAT"

    step "Creating media mount point..."
    mkdir -p /mnt/media
    success "Mount point created: /mnt/media"

    local DOCKER_DATA_ROOT="/var/lib/docker"  # Default location

    if [[ "$USE_EXTERNAL_HDD" == true ]] && [[ -n "$SELECTED_DRIVE" ]]; then
        step "Preparing external HDD: $SELECTED_DRIVE"

        # Check if partition exists
        local partition="${SELECTED_DRIVE}1"
        if [[ ! -b "$partition" ]]; then
            substep "Creating partition on $SELECTED_DRIVE..."
            parted -s "$SELECTED_DRIVE" mklabel gpt
            parted -s "$SELECTED_DRIVE" mkpart primary ext4 0% 100%
            sleep 2
            partition="${SELECTED_DRIVE}1"
            success "Partition created: $partition"
        fi

        # Check filesystem
        local fs_type=$(blkid -o value -s TYPE "$partition" 2>/dev/null || echo "")
        if [[ "$fs_type" != "ext4" ]]; then
            substep "Formatting $partition as ext4..."
            mkfs.ext4 -F -L mediahub "$partition" 2>&1 | head -20
            success "Partition formatted as ext4"
        else
            success "Partition already formatted as ext4"
        fi

        # Mount the drive
        substep "Mounting $partition to /mnt/media..."
        mount "$partition" /mnt/media 2>/dev/null || true
        success "HDD mounted to /mnt/media"

        # Add to fstab for auto-mount
        local uuid=$(blkid -s UUID -o value "$partition")
        if ! grep -q "$uuid" /etc/fstab; then
            substep "Adding to /etc/fstab for auto-mount..."
            echo "UUID=$uuid /mnt/media ext4 defaults,noatime,nofail 0 2" >> /etc/fstab
            success "Auto-mount configured"
        fi

        # Create media directories
        substep "Creating media directory structure..."
        mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads,docker}
        mkdir -p /mnt/media/library/photos/{originals,import}
        chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media
        chmod -R 755 /mnt/media
        success "Media directories created"

        # Save device for Scrutiny
        SCRUTINY_DEVICE="$SELECTED_DRIVE"

        # Set Docker data root to HDD (critical for space!)
        DOCKER_DATA_ROOT="/mnt/media/docker"
        substep "Docker images will be stored on HDD: $DOCKER_DATA_ROOT"

        # Show disk info
        df -h /mnt/media
    else
        warning "No external HDD selected"
        info "Using default paths (ensure /mnt/media is mounted)"
        warning "Docker images will use SD card space - may run out of space!"

        # Create directories anyway
        mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads}
        mkdir -p /mnt/media/library/photos/{originals,import}
        chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media 2>/dev/null || true
    fi

    # ========== DOCKER CONFIGURATION (AFTER HDD MOUNT) ==========
    step "Optimizing Docker configuration for Raspberry Pi..."
    mkdir -p /etc/docker

    # Stop Docker before changing data-root
    if [[ "$DOCKER_DATA_ROOT" != "/var/lib/docker" ]]; then
        substep "Stopping Docker to move data directory..."
        systemctl stop docker 2>/dev/null || true
        sleep 2
    fi

    cat > /etc/docker/daemon.json << DOCKERCONFIG
{
  "data-root": "$DOCKER_DATA_ROOT",
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
DOCKERCONFIG

    substep "Docker data directory: $DOCKER_DATA_ROOT"
    substep "Reduced concurrent downloads to 2"
    substep "Increased retry attempts to 10"
    substep "Added log rotation (10MB x 3 files)"

    step "Restarting Docker with new configuration..."
    systemctl start docker
    sleep 3

    # Verify Docker is using the correct data root
    local actual_root=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}')
    if [[ "$actual_root" == "$DOCKER_DATA_ROOT" ]]; then
        success "Docker configured to use: $DOCKER_DATA_ROOT"
    else
        warning "Docker Root Dir: $actual_root (expected: $DOCKER_DATA_ROOT)"
    fi

    success "Docker optimized for stable image downloads"

    # ========== PROJECT STRUCTURE ==========
    phase "CREATING PROJECT STRUCTURE"
    save_state "STRUCTURE"

    step "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
    success "Created $INSTALL_DIR"

    step "Creating subdirectories..."
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/data"
    success "Subdirectories created"

    step "Copying project files..."
    cp -rv "$PROJECT_DIR"/* "$INSTALL_DIR/" 2>&1 | head -50
    success "Project files copied"

    step "Making scripts executable..."
    chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
    ls -la "$INSTALL_DIR/scripts/"*.sh 2>/dev/null | head -20
    success "Scripts are now executable"

    # ========== PASSWORDS ==========
    phase "GENERATING PASSWORDS"
    save_state "PASSWORDS"

    step "Generating secure random passwords..."
    JELLYFIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    substep "Jellyfin password: Generated (${#JELLYFIN_PASSWORD} chars)"

    QBITTORRENT_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    substep "qBittorrent password: Generated (${#QBITTORRENT_PASSWORD} chars)"

    PHOTOPRISM_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    substep "PhotoPrism password: Generated (${#PHOTOPRISM_PASSWORD} chars)"

    GOTIFY_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    substep "Gotify password: Generated (${#GOTIFY_PASSWORD} chars)"

    success "All passwords generated"

    step "Encrypting credentials..."
    local creds_file="$INSTALL_DIR/.credentials.enc"
    cat << EOF | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$MASTER_PASSWORD" -out "$creds_file" 2>/dev/null
JELLYFIN_PASSWORD=$JELLYFIN_PASSWORD
QBITTORRENT_PASSWORD=$QBITTORRENT_PASSWORD
PHOTOPRISM_PASSWORD=$PHOTOPRISM_PASSWORD
GOTIFY_PASSWORD=$GOTIFY_PASSWORD
OPENVPN_USER=$OPENVPN_USER
OPENVPN_PASS=$OPENVPN_PASS
EOF
    chmod 600 "$creds_file"
    success "Credentials encrypted and saved"

    # ========== ENVIRONMENT FILE ==========
    phase "CREATING CONFIGURATION"
    save_state "ENV"

    step "Creating .env file..."
    create_env_file_verbose
    success ".env file created"

    step "Setting file permissions..."
    chmod 600 "$INSTALL_DIR/.env"
    ls -la "$INSTALL_DIR/.env"
    success "Permissions set (600)"

    # ========== SECURITY ==========
    phase "SECURITY HARDENING"
    save_state "SECURITY"

    step "Configuring firewall (UFW)..."
    if command -v ufw &> /dev/null; then
        ufw --force reset 2>&1 | head -5
        ufw default deny incoming 2>&1
        ufw default allow outgoing 2>&1
        ufw allow from 192.168.0.0/16 to any 2>&1
        ufw allow from 10.0.0.0/8 to any 2>&1
        ufw allow ssh 2>&1
        ufw --force enable 2>&1
        success "UFW firewall configured"
        ufw status verbose | head -20
    else
        warning "UFW not installed"
    fi

    step "Setting secure permissions..."
    chmod 700 "$INSTALL_DIR"
    success "Directory permissions secured"

    # ========== DOCKER IMAGES ==========
    phase "PULLING DOCKER IMAGES"
    save_state "DOCKER_PULL"

    cd "$INSTALL_DIR"

    # Function to pull images with retry logic
    pull_images_with_retry() {
        local compose_file="$1"
        local max_retries=3
        local retry_count=0
        local pull_success=false

        while [[ $retry_count -lt $max_retries ]] && [[ "$pull_success" == "false" ]]; do
            retry_count=$((retry_count + 1))

            if [[ $retry_count -gt 1 ]]; then
                warning "Retry attempt $retry_count of $max_retries..."
                sleep 10
            fi

            info "Attempt $retry_count: Starting image download..."
            local pull_exit_code=0

            if [[ -n "$compose_file" ]]; then
                # Use timeout to prevent hanging, run in foreground and wait for completion
                # Show progress but also log for error checking
                timeout 1800 docker compose -f "$compose_file" pull 2>&1 | tee /tmp/docker_pull.log | grep -E "(Pulling|Pull complete|Downloaded|Already exists|error|failed)" | head -300 || pull_exit_code=$?
            else
                # Use timeout to prevent hanging, run in foreground and wait for completion
                # Show progress but also log for error checking
                timeout 1800 docker compose pull 2>&1 | tee /tmp/docker_pull.log | grep -E "(Pulling|Pull complete|Downloaded|Already exists|error|failed)" | head -300 || pull_exit_code=$?
            fi

            # Check if pull was successful
            if [[ $pull_exit_code -eq 0 ]]; then
                pull_success=true
                info "All images downloaded successfully"
            elif grep -q "error\|timeout\|TLS handshake\|failed" /tmp/docker_pull.log 2>/dev/null; then
                warning "Errors detected during download"
                if [[ $retry_count -lt $max_retries ]]; then
                    warning "Will retry in 10 seconds..."
                fi
            else
                # Exit code non-zero but no clear error - might be partial success
                warning "Pull completed with warnings (exit code: $pull_exit_code)"
                pull_success=true
            fi
        done

        rm -f /tmp/docker_pull.log
        return $([[ "$pull_success" == "true" ]] && echo 0 || echo 1)
    }

    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        step "Using Pi3 limited mode configuration..."
        info "This will pull fewer images to conserve resources"

        if [[ -f docker-compose.pi3.yml ]]; then
            step "Pulling images (this may take 10-30 minutes)..."
            info "Automatic retry on timeout enabled (max 3 attempts)"
            if pull_images_with_retry "docker-compose.pi3.yml"; then
                success "Docker images pulled (limited mode)"
            else
                warning "Some images may have failed, continuing anyway..."
            fi
        else
            warning "docker-compose.pi3.yml not found"
            info "Will use standard compose file"
            pull_images_with_retry ""
        fi
    else
        step "Using full mode configuration..."
        step "Pulling all Docker images (this may take 15-45 minutes)..."
        info "Automatic retry on timeout enabled (max 3 attempts)"
        info "Progress will be shown below..."
        if pull_images_with_retry ""; then
            success "Docker images pulled (full mode)"
        else
            warning "Some images may have failed to download"
            info "Installation will continue - missing images will be pulled on container start"
        fi
    fi

    step "Listing downloaded images..."
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -50
    success "Images ready"

    # ========== STARTING SERVICES ==========
    phase "STARTING DOCKER CONTAINERS"
    save_state "START"

    step "Starting all services..."
    info "This will pull any missing images and start containers..."
    info "Please wait, this may take several minutes on first run..."

    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        docker compose -f docker-compose.pi3.yml up -d 2>&1 | tail -100
    else
        docker compose up -d 2>&1 | tail -100
    fi
    success "Docker compose up command executed"

    step "Waiting for images to download and containers to start..."
    local wait_count=0
    local max_wait=300  # 5 minutes max wait
    local containers_ready=false
    local last_count=0

    while [[ $wait_count -lt $max_wait ]] && [[ "$containers_ready" == "false" ]]; do
        local running=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)

        # Check if docker compose is still pulling images
        local still_pulling=false
        if docker compose ps 2>&1 | grep -q "Pulling"; then
            still_pulling=true
        fi

        # We're ready when we have a stable number of containers and not pulling
        if [[ $running -gt 15 ]] && [[ "$still_pulling" == "false" ]] && [[ $running -eq $last_count ]]; then
            containers_ready=true
        else
            echo -ne "\r  Containers running: $running | Elapsed: ${wait_count}s / ${max_wait}s    "
            sleep 10
            wait_count=$((wait_count + 10))
            last_count=$running
        fi
    done
    echo ""

    if [[ "$containers_ready" == "true" ]]; then
        success "All containers are running"
    else
        warning "Timeout reached, some containers may still be initializing"
        info "Checking current status..."
    fi

    step "Checking container status..."
    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        docker compose -f docker-compose.pi3.yml ps 2>&1
    else
        docker compose ps 2>&1
    fi

    local running_count=$(docker ps --format '{{.Names}}' | wc -l)
    success "$running_count containers running"

    step "Container health check..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -50

    # Additional wait if containers are still pulling
    if [[ $running_count -lt 15 ]]; then
        warning "Fewer containers than expected ($running_count). Some may still be downloading..."
        step "Waiting additional 2 minutes for slow services..."
        for i in {1..24}; do
            local current=$(docker ps --format '{{.Names}}' | wc -l)
            echo -ne "\r  Progress: $((i*5))/120 seconds | Running: $current containers    "
            sleep 5
        done
        echo ""
        running_count=$(docker ps --format '{{.Names}}' | wc -l)
        success "Now $running_count containers running"
    fi

    # ========== POST INSTALL ==========
    phase "POST-INSTALLATION SETUP"
    save_state "POST_CONFIG"

    # Only run post-install if we have enough containers running
    if [[ $running_count -lt 10 ]]; then
        warning "Not enough containers running ($running_count). Skipping post-install setup."
        info "You can run post-install setup manually later with:"
        info "  sudo bash $INSTALL_DIR/scripts/post-install-setup.sh"
    else
        step "Running post-install configuration..."
        if [[ -f "$INSTALL_DIR/scripts/post-install-setup.sh" ]]; then
            bash "$INSTALL_DIR/scripts/post-install-setup.sh" 2>&1 | head -100 || true
            success "Post-install script executed"
        else
            warning "post-install-setup.sh not found"
        fi
    fi

    # ========== FEATURES ==========
    phase "CONFIGURING OPTIONAL FEATURES"
    save_state "FEATURES"

    if [[ "$FEATURES" == *"TV_KIOSK"* ]]; then
        step "Setting up TV Kiosk mode..."
        setup_tv_kiosk_mode_verbose
        success "TV Kiosk mode configured"
    fi

    # ========== SYSTEMD SERVICE ==========
    phase "CONFIGURING AUTO-START"
    save_state "AUTOSTART"

    step "Creating systemd service..."
    setup_systemd_service_verbose
    success "Systemd service created"

    step "Enabling service..."
    systemctl daemon-reload
    systemctl enable mediahub.service 2>&1 | head -10
    success "MediaHub will start automatically on boot"

    # ========== HELPER SCRIPTS ==========
    phase "CREATING HELPER SCRIPTS"
    save_state "HELPERS"

    step "Creating password viewer script..."
    create_password_viewer
    success "show-passwords.sh created"

    # ========== COMPLETION ==========
    phase "INSTALLATION COMPLETE"
    save_state "COMPLETE"

    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  INSTALLATION SUCCESSFUL!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Access your services:${NC}"
    echo -e "  Dashboard:  ${CYAN}http://$ip:7575${NC}"
    echo -e "  Jellyfin:   ${CYAN}http://$ip:8096${NC}"
    echo -e "  Prowlarr:   ${CYAN}http://$ip:9696${NC}"
    echo -e "  Sonarr:     ${CYAN}http://$ip:8989${NC}"
    echo -e "  Radarr:     ${CYAN}http://$ip:7878${NC}"
    echo ""
    echo -e "${BOLD}Important commands:${NC}"
    echo -e "  View passwords:  ${YELLOW}$INSTALL_DIR/scripts/show-passwords.sh${NC}"
    echo -e "  Check status:    ${YELLOW}docker compose ps${NC}"
    echo -e "  View logs:       ${YELLOW}docker compose logs -f${NC}"
    echo ""
    echo -e "${BOLD}Hardware mode:${NC} $HARDWARE_MODE"
    echo -e "${BOLD}Install directory:${NC} $INSTALL_DIR"
    echo -e "${BOLD}Log file:${NC} $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Reboot recommended: sudo reboot${NC}"
    echo ""

    success "Installation completed at $(date)"
}

create_env_file_verbose() {
    info "Writing environment variables..."

    cat > "$INSTALL_DIR/.env" << EOF
# MediaHub Configuration
# Generated on $(date)
# Verbose installer

# User/Group IDs
PUID=$(id -u ${SUDO_USER:-pi})
PGID=$(id -g ${SUDO_USER:-pi})
TZ=Europe/Paris

# Paths
INSTALL_DIR=$INSTALL_DIR
CONFIG_PATH=$INSTALL_DIR/config
MEDIA_PATH=/mnt/media/library
DOWNLOAD_PATH=/mnt/media/downloads
BACKUP_PATH=$INSTALL_DIR/backups

# VPN Configuration
VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-none}
VPN_TYPE=${VPN_TYPE:-none}

# OpenVPN Credentials
OPENVPN_USER=${OPENVPN_USER:-}
OPENVPN_PASSWORD=${OPENVPN_PASS:-}

# Wireguard Credentials
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:-}
WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES:-}

# Server Selection
SERVER_COUNTRIES=${SERVER_COUNTRIES:-Netherlands}
SERVER_REGIONS=${SERVER_REGIONS:-}
SERVER_CITIES=${SERVER_CITIES:-}

# Service Passwords
JELLYFIN_USER=admin
JELLYFIN_PASSWORD=$JELLYFIN_PASSWORD
QBITTORRENT_USER=admin
QBITTORRENT_PASSWORD=$QBITTORRENT_PASSWORD
PHOTOPRISM_ADMIN_USER=admin
PHOTOPRISM_ADMIN_PASSWORD=$PHOTOPRISM_PASSWORD
GOTIFY_USER=admin
GOTIFY_PASSWORD=$GOTIFY_PASSWORD
PIHOLE_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

# Security
MASTER_PASSWORD_HASH=$(echo -n "$MASTER_PASSWORD" | sha256sum | cut -d' ' -f1)

# Feature Flags
ENABLE_TV_KIOSK=$([[ "$FEATURES" == *"TV_KIOSK"* ]] && echo "true" || echo "false")
ENABLE_HDMI_CEC=$([[ "$FEATURES" == *"HDMI_CEC"* ]] && echo "true" || echo "false")
ENABLE_NOTIFICATIONS=$([[ "$FEATURES" == *"NOTIFICATIONS"* ]] && echo "true" || echo "false")
ENABLE_MONITORING=$([[ "$FEATURES" == *"MONITORING"* ]] && echo "true" || echo "false")

# Hardware Mode
HARDWARE_MODE=${HARDWARE_MODE:-full}

# Scrutiny Disk Monitoring (set to your external HDD device)
SCRUTINY_DEVICE=${SCRUTINY_DEVICE:-/dev/sda}
EOF

    # Create backup directory
    mkdir -p "$INSTALL_DIR/backups" 2>/dev/null || true

    info "Environment file contents written"
}

setup_tv_kiosk_mode_verbose() {
    substep "Installing kiosk packages..."
    apt-get install -y -qq \
        chromium-browser xserver-xorg x11-xserver-utils \
        xinit openbox unclutter 2>&1 | head -20

    local user_home=$(eval echo ~${SUDO_USER:-pi})
    mkdir -p "$user_home/.config/openbox"

    substep "Creating openbox autostart..."
    cat > "$user_home/.config/openbox/autostart" << 'EOF'
xset s off
xset s noblank
xset -dpms
unclutter -idle 5 -root &
sleep 15
chromium-browser --kiosk --disable-infobars --no-first-run --start-fullscreen http://localhost:7575
EOF

    chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} "$user_home/.config/openbox"
    substep "Kiosk mode autostart configured"
}

setup_systemd_service_verbose() {
    local compose_cmd="docker compose up -d"
    local compose_stop="docker compose down"

    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        compose_cmd="docker compose -f docker-compose.pi3.yml up -d"
        compose_stop="docker compose -f docker-compose.pi3.yml down"
    fi

    substep "Creating /etc/systemd/system/mediahub.service"
    cat > /etc/systemd/system/mediahub.service << EOF
[Unit]
Description=MediaHub Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/$compose_cmd
ExecStop=/usr/bin/$compose_stop
User=${SUDO_USER:-pi}
Group=docker
Environment=HARDWARE_MODE=${HARDWARE_MODE}

[Install]
WantedBy=multi-user.target
EOF

    substep "Service file created"
    cat /etc/systemd/system/mediahub.service | head -20
}

create_password_viewer() {
    mkdir -p "$INSTALL_DIR/scripts" 2>/dev/null || true

    cat > "$INSTALL_DIR/scripts/show-passwords.sh" << 'EOF'
#!/bin/bash
INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

echo "========================================="
echo "  MediaHub - Password Viewer"
echo "========================================="
echo ""

read -sp "Enter master password: " master_pass
echo ""

stored_hash=$(grep "MASTER_PASSWORD_HASH" "$INSTALL_DIR/.env" | cut -d'=' -f2)
input_hash=$(echo -n "$master_pass" | sha256sum | cut -d' ' -f1)

if [[ "$stored_hash" != "$input_hash" ]]; then
    echo "Incorrect password!"
    exit 1
fi

echo ""
echo "Your credentials:"
echo "========================================="

openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass pass:"$master_pass" \
    -in "$INSTALL_DIR/.credentials.enc" 2>/dev/null
EOF
    chmod +x "$INSTALL_DIR/scripts/show-passwords.sh"
}

# ===========================================
# Main Wizard Flow
# ===========================================
main() {
    # Must be root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi

    # Initialize log
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "=== MediaHub Verbose Wizard Started ==="

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  MEDIAHUB INSTALLATION WIZARD - VERBOSE MODE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "This installer will show ${BOLD}ALL${NC} installation steps in real-time."
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    echo ""

    # Check/install TUI tool
    check_tui_tool

    # Select language
    select_language
    log "Language selected: $MEDIAHUB_LANG"

    # Hardware detection and mode selection
    select_hardware_mode

    # Welcome screen
    show_welcome

    # Check requirements
    if ! show_requirements; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi

    # Get VPN credentials
    if ! get_vpn_credentials; then
        exit 1
    fi

    # Master password
    if ! get_master_password; then
        exit 1
    fi

    # Select HDD
    if ! select_hdd; then
        exit 1
    fi

    # Select features
    select_features

    # Show summary and confirm
    if ! show_summary; then
        echo -e "${YELLOW}Installation cancelled by user.${NC}"
        exit 0
    fi

    # Clear screen for installation output
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  STARTING VERBOSE INSTALLATION${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Run installation with full output
    run_installation

    # Create helper scripts
    create_password_viewer

    # Cleanup
    rm -f "$STATE_FILE"

    log "=== MediaHub Verbose Wizard Completed Successfully ==="
}

main "$@"
