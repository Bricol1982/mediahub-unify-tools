#!/bin/bash
set -e

# MediaHub Unify Tools - Main Installation Script
# Optimized for Raspberry Pi 4 with Raspberry Pi OS (64-bit)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
INSTALL_DIR="/opt/mediahub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_warning "This system doesn't appear to be a Raspberry Pi"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_memory() {
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 3500 ]]; then
        log_warning "Less than 4GB RAM detected ($total_mem MB)"
        log_warning "Some services may not run properly"
    elif [[ $total_mem -gt 7000 ]]; then
        log_success "8GB RAM detected - Optimal configuration!"
        log_info "All services including Photoprism AI will run smoothly"
    else
        log_success "Memory check passed: ${total_mem}MB available"
    fi
}

update_system() {
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing dependencies..."
    apt-get install -y \
        curl \
        wget \
        git \
        htop \
        iotop \
        vim \
        nano \
        ufw \
        fail2ban \
        unattended-upgrades \
        apt-listchanges \
        logrotate \
        cec-utils \
        hdparm \
        smartmontools \
        usbutils \
        ntfs-3g \
        exfat-fuse \
        exfat-utils
    log_success "Dependencies installed"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        docker --version
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh

        # Add current user to docker group
        usermod -aG docker $SUDO_USER

        log_success "Docker installed"
    fi

    # Install Docker Compose
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose already installed"
    else
        log_info "Installing Docker Compose..."
        apt-get install -y docker-compose-plugin
        log_success "Docker Compose installed"
    fi
}

configure_swap() {
    log_info "Configuring swap for better performance..."

    # Increase swap size to 2GB
    if [[ -f /etc/dphys-swapfile ]]; then
        sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
        systemctl restart dphys-swapfile
        log_success "Swap configured to 2GB"
    else
        # Create swap file manually
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_success "2GB swap file created"
    fi
}

optimize_raspberry_pi() {
    log_info "Optimizing Raspberry Pi settings..."

    # GPU memory split (reduce GPU memory since we're not using desktop)
    if [[ -f /boot/config.txt ]]; then
        if ! grep -q "gpu_mem=" /boot/config.txt; then
            echo "gpu_mem=128" >> /boot/config.txt
        fi

        # Enable hardware acceleration
        if ! grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
            echo "dtoverlay=vc4-fkms-v3d" >> /boot/config.txt
        fi
    fi

    # Optimize kernel parameters
    cat > /etc/sysctl.d/99-mediahub.conf << EOF
# MediaHub optimizations
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
net.core.somaxconn=1024
net.ipv4.tcp_tw_reuse=1
fs.inotify.max_user_watches=524288
EOF

    sysctl --system
    log_success "Raspberry Pi optimized"
}

setup_directories() {
    log_info "Creating directory structure..."

    # Create main directories
    mkdir -p $INSTALL_DIR/{config,logs}
    mkdir -p /mnt/media/{downloads,library,backups,recordings}
    mkdir -p /mnt/media/library/{movies,tv,music,books}
    mkdir -p /mnt/media/downloads/{complete,incomplete}

    # Set permissions
    chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR
    chown -R $SUDO_USER:$SUDO_USER /mnt/media

    log_success "Directories created"
}

setup_external_hdd() {
    log_info "Setting up external HDD..."

    # Detect external drives
    echo "Detected block devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | grep -E "sd|nvme"

    echo ""
    read -p "Enter the device to mount (e.g., /dev/sda1) or press Enter to skip: " device

    if [[ -n "$device" ]]; then
        # Get filesystem type
        local fstype=$(blkid -s TYPE -o value "$device" 2>/dev/null)

        if [[ -z "$fstype" ]]; then
            log_warning "Could not detect filesystem type"
            read -p "Format the drive as ext4? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkfs.ext4 "$device"
                fstype="ext4"
            else
                return
            fi
        fi

        # Mount the drive
        mount "$device" /mnt/media

        # Add to fstab for auto-mount
        local uuid=$(blkid -s UUID -o value "$device")
        echo "UUID=$uuid /mnt/media $fstype defaults,nofail,x-systemd.device-timeout=30 0 2" >> /etc/fstab

        log_success "External HDD mounted at /mnt/media"
    else
        log_warning "Skipping external HDD setup"
    fi
}

copy_project_files() {
    log_info "Copying project files..."

    # Copy docker-compose and configs
    cp -r "$PROJECT_DIR"/* $INSTALL_DIR/
    cp "$PROJECT_DIR"/.env.example $INSTALL_DIR/.env.example

    # Create .env from example if not exists
    if [[ ! -f $INSTALL_DIR/.env ]]; then
        cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env
        log_warning "Please edit $INSTALL_DIR/.env with your configuration"
    fi

    # Set permissions
    chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR
    chmod +x $INSTALL_DIR/scripts/*.sh

    log_success "Project files copied to $INSTALL_DIR"
}

configure_firewall() {
    log_info "Configuring firewall..."

    ufw default deny incoming
    ufw default allow outgoing

    # SSH
    ufw allow 22/tcp

    # Web interfaces
    ufw allow 80/tcp    # Heimdall
    ufw allow 443/tcp   # HTTPS
    ufw allow 8096/tcp  # Jellyfin
    ufw allow 9000/tcp  # Portainer
    ufw allow 8080/tcp  # qBittorrent (through VPN)

    # Enable firewall
    echo "y" | ufw enable

    log_success "Firewall configured"
}

setup_fail2ban() {
    log_info "Configuring fail2ban..."

    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    log_success "Fail2ban configured"
}

install_log2ram() {
    log_info "Installing log2ram to reduce SD card wear..."

    echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ bookworm main" | tee /etc/apt/sources.list.d/azlux.list
    wget -O /usr/share/keyrings/azlux-archive-keyring.gpg https://azlux.fr/repo.gpg
    apt-get update
    apt-get install -y log2ram

    # Configure log2ram
    sed -i 's/SIZE=.*/SIZE=128M/' /etc/log2ram.conf

    log_success "log2ram installed"
}

setup_cec() {
    log_info "Setting up HDMI-CEC for TV remote control..."

    bash "$INSTALL_DIR/config/cec/cec-config.sh"

    log_success "CEC configured"
}

create_management_scripts() {
    log_info "Creating management scripts..."

    # Link to the full-featured scripts from scripts/ directory
    # These scripts have error handling, status checks, and better UX

    # Create symlinks if scripts exist in the project
    if [[ -f "$INSTALL_DIR/scripts/start.sh" ]]; then
        ln -sf "$INSTALL_DIR/scripts/start.sh" "$INSTALL_DIR/start.sh"
        ln -sf "$INSTALL_DIR/scripts/stop.sh" "$INSTALL_DIR/stop.sh"
        ln -sf "$INSTALL_DIR/scripts/update.sh" "$INSTALL_DIR/update.sh"
        ln -sf "$INSTALL_DIR/scripts/status.sh" "$INSTALL_DIR/status.sh"
        log_success "Management scripts linked from scripts/ directory"
    else
        # Fallback: create basic scripts if advanced ones don't exist
        cat > $INSTALL_DIR/start.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose up -d
echo "MediaHub services started"
docker compose ps
EOF

        cat > $INSTALL_DIR/stop.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose down
echo "MediaHub services stopped"
EOF

        cat > $INSTALL_DIR/update.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose pull
docker compose down
docker compose up -d
docker image prune -f
echo "MediaHub services updated"
EOF

        cat > $INSTALL_DIR/status.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose ps
echo ""
echo "System Resources:"
free -h
echo ""
df -h /mnt/media
EOF
        log_success "Basic management scripts created"
    fi

    chmod +x $INSTALL_DIR/*.sh 2>/dev/null || true
    chmod +x $INSTALL_DIR/scripts/*.sh 2>/dev/null || true
    chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR/*.sh 2>/dev/null || true

    log_success "Management scripts ready"
}

setup_auto_start() {
    log_info "Configuring auto-start on boot..."

    cat > /etc/systemd/system/mediahub.service << EOF
[Unit]
Description=MediaHub Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$SUDO_USER
Group=docker

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mediahub.service

    log_success "Auto-start configured"
}

setup_automated_backups() {
    log_info "Setting up automated configuration backups..."

    # Create backup directory
    mkdir -p /mnt/media/backups/mediahub

    # Make backup script executable
    chmod +x "$INSTALL_DIR/scripts/backup-config.sh"
    chmod +x "$INSTALL_DIR/scripts/restore-config.sh"

    # Create cron job for daily backup at 3 AM
    local cron_job="0 3 * * * $INSTALL_DIR/scripts/backup-config.sh --quick >> /var/log/mediahub-backup.log 2>&1"

    # Add to root crontab
    if ! crontab -l 2>/dev/null | grep -q "backup-config.sh"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log_success "Daily backup scheduled at 3:00 AM"
    fi

    # Create initial backup after first start
    cat > "$INSTALL_DIR/scripts/initial-backup.sh" << 'EOF'
#!/bin/bash
# Wait for services to be configured, then create initial backup
sleep 300  # Wait 5 minutes after first start
/opt/mediahub/scripts/backup-config.sh --quick
rm -f /opt/mediahub/scripts/initial-backup.sh
EOF
    chmod +x "$INSTALL_DIR/scripts/initial-backup.sh"

    log_success "Automated backups configured"
    log_info "Backups will be stored in /mnt/media/backups/mediahub/"
    log_info "Keeping last 10 backups with 7-day retention"
}

print_summary() {
    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "========================================="
    echo -e "${GREEN}MediaHub Installation Complete!${NC}"
    echo "========================================="
    echo ""
    echo "Installation directory: $INSTALL_DIR"
    echo "Media directory: /mnt/media"
    echo ""
    echo "Important next steps:"
    echo "1. Edit configuration: nano $INSTALL_DIR/.env"
    echo "2. Configure ProtonVPN credentials"
    echo "3. Start services: $INSTALL_DIR/start.sh"
    echo "4. Reboot to apply all changes: sudo reboot"
    echo ""
    echo "Service URLs (after starting):"
    echo "  - Heimdall (Dashboard): http://$ip/"
    echo "  - Jellyfin (Media Server): http://$ip:8096"
    echo "  - Sonarr (TV Shows): http://$ip:8989"
    echo "  - Radarr (Movies): http://$ip:7878"
    echo "  - Lidarr (Music): http://$ip:8686"
    echo "  - Prowlarr (Indexers): http://$ip:9696"
    echo "  - qBittorrent: http://$ip:8080"
    echo "  - Jellyseerr (Requests): http://$ip:5055"
    echo "  - Portainer (Docker): http://$ip:9000"
    echo "  - Pi-hole: http://$ip:8053/admin"
    echo "  - Threadfin (IPTV): http://$ip:34400/web"
    echo "  - Netdata: http://$ip:19999"
    echo ""
    echo "Management commands:"
    echo "  Start:  $INSTALL_DIR/start.sh"
    echo "  Stop:   $INSTALL_DIR/stop.sh"
    echo "  Update: $INSTALL_DIR/update.sh"
    echo "  Status: $INSTALL_DIR/status.sh"
    echo ""
    echo "Backup & Recovery:"
    echo "  Backup: $INSTALL_DIR/scripts/backup-config.sh"
    echo "  Restore: $INSTALL_DIR/scripts/restore-config.sh <backup.tar.gz>"
    echo "  Status: $INSTALL_DIR/scripts/backup-config.sh --status"
    echo ""
    log_info "Automated backups run daily at 3:00 AM"
    log_info "Backups stored in /mnt/media/backups/mediahub/"
    echo ""
    log_warning "Please reboot your Raspberry Pi to apply all changes"
}

# Main installation
main() {
    echo "========================================="
    echo "  MediaHub Unify Tools Installer"
    echo "  For Raspberry Pi 4"
    echo "========================================="
    echo ""

    check_root
    check_raspberry_pi
    check_memory

    echo ""
    echo "Installation modes:"
    echo "  1) AUTOMATIC - One-command installation with auto-generated passwords"
    echo "     - Minimal user input (ProtonVPN creds, master password, HDD)"
    echo "     - Auto-generates secure passwords for all services"
    echo "     - Encrypted password storage with master password"
    echo "     - Full system optimization and security setup"
    echo ""
    echo "  2) MANUAL - Step-by-step installation with custom configuration"
    echo "     - Manual service configuration"
    echo "     - Custom password setup"
    echo "     - More control over each step"
    echo ""

    read -p "Choose installation mode (1=Auto/2=Manual) [1]: " install_mode
    install_mode=${install_mode:-1}

    if [[ "$install_mode" == "1" ]]; then
        log_info "Launching automated installer with password management..."
        echo ""

        # Check if auto-install script exists
        if [[ -f "$SCRIPT_DIR/auto-install.sh" ]]; then
            exec bash "$SCRIPT_DIR/auto-install.sh"
        else
            log_error "Auto-install script not found at $SCRIPT_DIR/auto-install.sh"
            log_info "Falling back to manual installation..."
        fi
    fi

    # Manual installation continues here
    read -p "This will install MediaHub (manual mode). Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi

    update_system
    install_dependencies
    install_docker
    configure_swap
    optimize_raspberry_pi
    setup_directories
    setup_external_hdd
    copy_project_files
    configure_firewall
    setup_fail2ban
    install_log2ram
    create_management_scripts
    setup_auto_start
    setup_automated_backups

    read -p "Configure HDMI-CEC for TV remote? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_cec
    fi

    print_summary
}

# Run main function
main "$@"
