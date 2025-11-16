#!/bin/bash
# MediaHub Automatic Installation Script
# One-command installation with automatic password generation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/mediahub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/mediahub-install.log"

# Installation state
PHASE=0
TOTAL_PHASES=12

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

phase() {
    ((PHASE++))
    echo ""
    echo -e "${CYAN}[$PHASE/$TOTAL_PHASES] $1${NC}"
    log "PHASE $PHASE: $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

detect_hardware() {
    phase "Detecting hardware..."

    # Check if Raspberry Pi
    if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null || grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        RPI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")
        log_success "Detected: $RPI_MODEL"
    else
        log_warning "Not a Raspberry Pi - some features may not work"
        RPI_MODEL="Generic Linux"
    fi

    # Check RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/ {print $2}')
    if [[ $TOTAL_RAM -gt 7000 ]]; then
        log_success "RAM: ${TOTAL_RAM}MB (Optimal for all services)"
        RAM_CONFIG="full"
        HARDWARE_MODE="full"
    elif [[ $TOTAL_RAM -gt 3000 ]]; then
        log_success "RAM: ${TOTAL_RAM}MB (Full mode supported)"
        RAM_CONFIG="full"
        HARDWARE_MODE="full"
    elif [[ $TOTAL_RAM -gt 900 ]]; then
        log_warning "RAM: ${TOTAL_RAM}MB (Limited mode - Pi3 compatible)"
        RAM_CONFIG="limited"
        HARDWARE_MODE="limited"
    else
        log_error "RAM: ${TOTAL_RAM}MB (Insufficient for MediaHub - minimum 1GB)"
        exit 1
    fi

    # Detect external HDD
    log_info "Scanning for external storage..."
    EXTERNAL_DISKS=$(lsblk -d -o NAME,SIZE,MODEL,TRAN 2>/dev/null | grep -E "usb|sata" | grep -v "boot" || true)

    if [[ -n "$EXTERNAL_DISKS" ]]; then
        echo "$EXTERNAL_DISKS"
        HDD_DETECTED=true
    else
        log_warning "No external USB storage detected"
        HDD_DETECTED=false
    fi
}

get_user_input() {
    phase "Configuration..."

    echo ""
    echo -e "${YELLOW}=== ProtonVPN Configuration ===${NC}"
    echo "You need ProtonVPN OpenVPN credentials (NOT account login)"
    echo "Get them from: https://account.protonvpn.com/account#openvpn"
    echo ""

    read -p "ProtonVPN OpenVPN Username: " PROTON_USER
    while [[ -z "$PROTON_USER" ]]; do
        echo -e "${RED}Username cannot be empty${NC}"
        read -p "ProtonVPN OpenVPN Username: " PROTON_USER
    done

    read -sp "ProtonVPN OpenVPN Password: " PROTON_PASS
    echo ""
    while [[ -z "$PROTON_PASS" ]]; do
        echo -e "${RED}Password cannot be empty${NC}"
        read -sp "ProtonVPN OpenVPN Password: " PROTON_PASS
        echo ""
    done

    echo ""
    echo "VPN Server Location:"
    echo "  1. Netherlands (recommended)"
    echo "  2. Switzerland"
    echo "  3. Sweden"
    echo "  4. France"
    read -p "Select [1]: " vpn_choice
    vpn_choice=${vpn_choice:-1}

    case $vpn_choice in
        1) VPN_COUNTRY="Netherlands" ;;
        2) VPN_COUNTRY="Switzerland" ;;
        3) VPN_COUNTRY="Sweden" ;;
        4) VPN_COUNTRY="France" ;;
        *) VPN_COUNTRY="Netherlands" ;;
    esac

    echo ""
    echo -e "${YELLOW}=== Master Password ===${NC}"
    echo "Create a master password to encrypt all service credentials."
    echo "You'll need this to view or reset passwords later."
    echo ""

    while true; do
        read -sp "Master Password (min 8 chars): " MASTER_PASSWORD
        echo ""
        if [[ ${#MASTER_PASSWORD} -lt 8 ]]; then
            echo -e "${RED}Password too short${NC}"
            continue
        fi

        read -sp "Confirm Master Password: " MASTER_CONFIRM
        echo ""

        if [[ "$MASTER_PASSWORD" == "$MASTER_CONFIRM" ]]; then
            break
        else
            echo -e "${RED}Passwords do not match${NC}"
        fi
    done

    # External HDD
    if [[ "$HDD_DETECTED" == true ]]; then
        echo ""
        echo -e "${YELLOW}=== External HDD Configuration ===${NC}"
        lsblk -d -o NAME,SIZE,MODEL | grep -E "sd"
        echo ""
        read -p "Enter disk to use (e.g., sda) or 'skip' to skip: " HDD_DEVICE

        if [[ "$HDD_DEVICE" != "skip" ]] && [[ -b "/dev/$HDD_DEVICE" ]]; then
            echo ""
            echo -e "${RED}WARNING: This will ERASE ALL DATA on /dev/$HDD_DEVICE${NC}"
            read -p "Type 'YES' to confirm: " confirm
            if [[ "$confirm" == "YES" ]]; then
                FORMAT_HDD=true
            else
                FORMAT_HDD=false
            fi
        else
            FORMAT_HDD=false
        fi
    else
        FORMAT_HDD=false
    fi

    # TV Kiosk
    echo ""
    read -p "Setup TV kiosk mode (display dashboard on HDMI)? (y/N) " -n 1 -r
    echo ""
    SETUP_KIOSK=$([[ $REPLY =~ ^[Yy]$ ]] && echo true || echo false)

    # HDMI-CEC
    read -p "Configure TV remote control (HDMI-CEC)? (y/N) " -n 1 -r
    echo ""
    SETUP_CEC=$([[ $REPLY =~ ^[Yy]$ ]] && echo true || echo false)
}

update_system() {
    phase "Updating system packages..."
    apt-get update -qq
    apt-get upgrade -y -qq
    log_success "System updated"
}

install_dependencies() {
    phase "Installing dependencies..."

    apt-get install -y -qq \
        curl \
        wget \
        git \
        jq \
        openssl \
        ufw \
        fail2ban \
        htop \
        rsync \
        tree \
        dnsutils \
        > /dev/null 2>&1

    log_success "Dependencies installed"
}

install_docker() {
    phase "Installing Docker..."

    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
    else
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
        usermod -aG docker ${SUDO_USER:-pi}
    fi

    # Docker Compose plugin
    if ! docker compose version &> /dev/null; then
        apt-get install -y -qq docker-compose-plugin > /dev/null 2>&1
    fi

    systemctl enable docker
    systemctl start docker

    log_success "Docker installed and configured"
}

optimize_system() {
    phase "Optimizing system for MediaHub..."

    # Increase swap
    if [[ -f /etc/dphys-swapfile ]]; then
        sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
        systemctl restart dphys-swapfile
    fi

    # GPU memory (Raspberry Pi)
    if [[ -f /boot/config.txt ]]; then
        if ! grep -q "gpu_mem=128" /boot/config.txt; then
            echo "gpu_mem=128" >> /boot/config.txt
        fi
    fi

    # Kernel optimizations
    cat >> /etc/sysctl.conf << 'EOF'
# MediaHub optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
    sysctl -p > /dev/null 2>&1

    # Install log2ram
    if ! command -v log2ram &> /dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ bookworm main" | tee /etc/apt/sources.list.d/azlux.list > /dev/null
        wget -qO /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg 2>/dev/null || true
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq log2ram > /dev/null 2>&1 || true
    fi

    log_success "System optimized"
}

setup_hdd() {
    phase "Setting up external storage..."

    if [[ "$FORMAT_HDD" == true ]]; then
        log_info "Formatting /dev/$HDD_DEVICE..."

        # Unmount if mounted
        umount /dev/${HDD_DEVICE}* 2>/dev/null || true

        # Create partition table
        parted -s "/dev/$HDD_DEVICE" mklabel gpt
        parted -s "/dev/$HDD_DEVICE" mkpart primary ext4 0% 100%
        sleep 2
        partprobe "/dev/$HDD_DEVICE"
        sleep 2

        # Format
        PARTITION="/dev/${HDD_DEVICE}1"
        mkfs.ext4 -L "MediaHub" "$PARTITION" > /dev/null 2>&1

        # Mount
        mkdir -p /mnt/media
        mount "$PARTITION" /mnt/media

        # Add to fstab
        local uuid=$(blkid -s UUID -o value "$PARTITION")
        if ! grep -q "$uuid" /etc/fstab; then
            echo "UUID=$uuid /mnt/media ext4 defaults,noatime,nofail 0 2" >> /etc/fstab
        fi

        # Create directory structure
        mkdir -p /mnt/media/{downloads,library,backups,recordings}
        mkdir -p /mnt/media/downloads/{complete,incomplete}
        mkdir -p /mnt/media/library/{movies,tv,music,books,photos,comics}
        mkdir -p /mnt/media/library/photos/{originals,import}
        mkdir -p /mnt/media/library/comics/{series,oneshots}
        mkdir -p /mnt/media/backups/mediahub

        chown -R ${SUDO_USER:-1000}:${SUDO_USER:-1000} /mnt/media
        chmod -R 755 /mnt/media

        log_success "HDD formatted and mounted at /mnt/media"
    else
        # Just create mount point
        mkdir -p /mnt/media
        log_info "Using existing storage configuration"
    fi
}

install_mediahub() {
    phase "Installing MediaHub..."

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Copy project files
    cp -r "$PROJECT_DIR"/* "$INSTALL_DIR/"
    cp "$PROJECT_DIR"/.env.example "$INSTALL_DIR/.env" 2>/dev/null || true
    cp "$PROJECT_DIR"/.gitignore "$INSTALL_DIR/" 2>/dev/null || true

    # Configure .env
    local puid=$(id -u ${SUDO_USER:-1000})
    local pgid=$(id -g ${SUDO_USER:-1000})

    sed -i "s|^PUID=.*|PUID=$puid|" "$INSTALL_DIR/.env"
    sed -i "s|^PGID=.*|PGID=$pgid|" "$INSTALL_DIR/.env"
    sed -i "s|^PROTON_USER=.*|PROTON_USER=$PROTON_USER|" "$INSTALL_DIR/.env"
    sed -i "s|^PROTON_PASS=.*|PROTON_PASS=$PROTON_PASS|" "$INSTALL_DIR/.env"
    sed -i "s|^VPN_COUNTRY=.*|VPN_COUNTRY=$VPN_COUNTRY|" "$INSTALL_DIR/.env"

    # Set permissions
    chown -R ${SUDO_USER:-1000}:${SUDO_USER:-1000} "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR"/scripts/*.sh

    # Create symlinks for easy access
    ln -sf "$INSTALL_DIR/scripts/start.sh" "$INSTALL_DIR/start.sh"
    ln -sf "$INSTALL_DIR/scripts/stop.sh" "$INSTALL_DIR/stop.sh"
    ln -sf "$INSTALL_DIR/scripts/update.sh" "$INSTALL_DIR/update.sh"
    ln -sf "$INSTALL_DIR/scripts/status.sh" "$INSTALL_DIR/status.sh"

    log_success "MediaHub installed to $INSTALL_DIR"
}

generate_passwords() {
    phase "Generating secure passwords..."

    # Use password manager to generate and encrypt credentials
    cd "$INSTALL_DIR"

    # Generate passwords
    source "$INSTALL_DIR/scripts/password-manager.sh"

    # Create credentials file with master password
    create_credentials_file "$MASTER_PASSWORD"

    log_success "Passwords generated and encrypted"
    log_info "View passwords: $INSTALL_DIR/scripts/password-manager.sh show"
}

configure_security() {
    phase "Configuring security..."

    # Firewall
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1

    # Allow SSH
    ufw allow ssh > /dev/null 2>&1

    # Allow MediaHub ports
    local ports=(80 443 7575 8096 8989 7878 8686 9696 8080 5055 6767 8787 8090 25600 4533 34400 9000 3001 8053 19999 8191 2342 51820/udp)
    for port in "${ports[@]}"; do
        ufw allow "$port" > /dev/null 2>&1
    done

    ufw --force enable > /dev/null 2>&1

    # Fail2ban
    systemctl enable fail2ban > /dev/null 2>&1
    systemctl start fail2ban > /dev/null 2>&1

    log_success "Security configured (UFW + Fail2ban)"
}

setup_autostart() {
    phase "Configuring auto-start..."

    # Determine compose command based on hardware mode
    local compose_start="docker compose up -d"
    local compose_stop="docker compose down"

    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        compose_start="docker compose -f docker-compose.pi3.yml up -d"
        compose_stop="docker compose -f docker-compose.pi3.yml down"
    fi

    cat > /etc/systemd/system/mediahub.service << EOF
[Unit]
Description=MediaHub Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/$compose_start
ExecStop=/usr/bin/$compose_stop
User=${SUDO_USER:-pi}
Group=docker
Environment=HARDWARE_MODE=${HARDWARE_MODE:-full}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mediahub.service > /dev/null 2>&1

    # Automated backups
    local cron_job="0 3 * * * $INSTALL_DIR/scripts/backup-config.sh --quick >> /var/log/mediahub-backup.log 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "backup-config.sh"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    fi

    log_success "Auto-start and automated backups configured"
}

setup_tv_display() {
    if [[ "$SETUP_KIOSK" == true ]]; then
        phase "Setting up TV kiosk mode..."

        # Install minimal X server and Chromium
        apt-get install -y -qq chromium-browser xserver-xorg x11-xserver-utils xinit openbox unclutter > /dev/null 2>&1

        # Configure openbox autostart
        local user_home=$(eval echo ~${SUDO_USER:-pi})
        mkdir -p "$user_home/.config/openbox"

        cat > "$user_home/.config/openbox/autostart" << 'EOF'
xset s off
xset s noblank
xset -dpms
unclutter -idle 5 -root &
sleep 10
chromium-browser --kiosk --disable-infobars --no-first-run --start-fullscreen http://localhost:7575
EOF

        chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} "$user_home/.config/openbox"

        log_success "TV kiosk mode configured"
    fi

    if [[ "$SETUP_CEC" == true ]]; then
        log_info "Setting up HDMI-CEC..."
        apt-get install -y -qq cec-utils > /dev/null 2>&1
        log_success "HDMI-CEC installed"
    fi
}

start_services() {
    phase "Starting MediaHub services..."

    cd "$INSTALL_DIR"

    # Determine compose file based on hardware mode
    local compose_file=""
    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        compose_file="-f docker-compose.pi3.yml"
        log_info "Using limited mode (Pi3) configuration..."
    fi

    log_info "Pulling Docker images (this may take 10-30 minutes)..."
    docker compose $compose_file pull 2>&1 | grep -E "Pulling|Downloaded" | head -20 || true

    log_info "Starting containers..."
    docker compose $compose_file up -d 2>&1 | head -20 || true

    # Wait for services
    log_info "Waiting for services to initialize..."
    sleep 30

    # Count running
    local running=$(docker compose $compose_file ps --status running 2>/dev/null | tail -n +2 | wc -l)
    log_success "$running services started"
}

run_post_install_setup() {
    phase "Running automated post-installation setup..."

    if [[ -f "$INSTALL_DIR/scripts/post-install-setup.sh" ]]; then
        log_info "Configuring service connections, API keys, and integrations..."
        bash "$INSTALL_DIR/scripts/post-install-setup.sh"
        log_success "Post-installation automation complete"
    else
        log_warning "Post-install script not found, skipping automated setup"
    fi
}

print_summary() {
    local ip=$(hostname -I | awk '{print $1}')

    clear
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  MediaHub Installation Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "${CYAN}System Information:${NC}"
    echo "  Device: $RPI_MODEL"
    echo "  RAM: ${TOTAL_RAM}MB"
    echo "  IP Address: $ip"
    echo ""
    echo -e "${CYAN}Important URLs:${NC}"
    echo "  Dashboard:   http://$ip:7575"
    echo "  Jellyfin:    http://$ip:8096"
    echo "  Sonarr:      http://$ip:8989"
    echo "  Radarr:      http://$ip:7878"
    echo "  qBittorrent: http://$ip:8080"
    echo ""
    echo -e "${CYAN}Credentials:${NC}"
    echo "  All passwords are encrypted with your master password."
    echo "  View them: /opt/mediahub/scripts/password-manager.sh show"
    echo "  Reset them: /opt/mediahub/scripts/password-manager.sh reset"
    echo ""
    echo -e "${CYAN}Management:${NC}"
    echo "  Start:   /opt/mediahub/start.sh"
    echo "  Stop:    /opt/mediahub/stop.sh"
    echo "  Status:  /opt/mediahub/status.sh"
    echo "  Health:  /opt/mediahub/scripts/health-check.sh"
    echo ""
    echo -e "${CYAN}Backups:${NC}"
    echo "  Automated daily at 3:00 AM"
    echo "  Location: /mnt/media/backups/mediahub/"
    echo "  Manual: /opt/mediahub/scripts/backup-config.sh"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. View your passwords: /opt/mediahub/scripts/password-manager.sh show"
    echo "  2. Check VPN: docker exec gluetun wget -qO- https://ipinfo.io"
    echo "  3. Configure Jellyfin (first-time setup wizard)"
    echo "  4. Set up Sonarr/Radarr download clients"
    echo ""
    echo -e "${RED}IMPORTANT:${NC}"
    echo "  Your master password is the ONLY way to access credentials."
    echo "  Store it safely! If lost, you'll need to reset all passwords."
    echo ""
    echo -e "${GREEN}Installation log: $LOG_FILE${NC}"
    echo ""

    # Save summary to file
    cat > "$INSTALL_DIR/INSTALL_SUMMARY.txt" << EOF
MediaHub Installation Summary
Generated: $(date)

IP Address: $ip
Dashboard: http://$ip:7575

View Credentials:
  /opt/mediahub/scripts/password-manager.sh show

Management Commands:
  /opt/mediahub/start.sh
  /opt/mediahub/stop.sh
  /opt/mediahub/status.sh

Backup Location:
  /mnt/media/backups/mediahub/

Configuration:
  /opt/mediahub/.env
EOF

    echo -e "${YELLOW}Reboot recommended to apply all changes: sudo reboot${NC}"
    echo ""
}

main() {
    # Check root FIRST (before trying to write to /var/log)
    check_root

    # Start log (now we have root permissions)
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "=== MediaHub Automatic Installation Started ==="

    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  MediaHub Automatic Installer${NC}"
    echo -e "${CYAN}  Version 1.0${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    detect_hardware
    get_user_input

    echo ""
    echo -e "${YELLOW}Starting installation...${NC}"
    echo "This process will take 15-45 minutes depending on your internet speed."
    echo ""

    update_system
    install_dependencies
    install_docker
    optimize_system
    setup_hdd
    install_mediahub
    generate_passwords
    configure_security
    setup_autostart
    setup_tv_display
    start_services
    run_post_install_setup

    log "=== Installation Complete ==="

    print_summary
}

main "$@"
