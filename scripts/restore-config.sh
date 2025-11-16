#!/bin/bash
# Restore MediaHub configurations from backup after SD card failure
# This script helps recover your entire setup quickly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_usage() {
    echo "MediaHub Configuration Restore"
    echo ""
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Example:"
    echo "  sudo $0 /mnt/media/backups/mediahub/mediahub_backup_20240115_030000.tar.gz"
    echo ""
    echo "This script will:"
    echo "  1. Install Docker if not present"
    echo "  2. Extract backup to /opt/mediahub/"
    echo "  3. Restore all service configurations"
    echo "  4. Start all Docker containers"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_backup_file() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi

    if [[ ! "$backup_file" =~ \.tar\.gz$ ]]; then
        log_error "Backup file must be a .tar.gz archive"
        exit 1
    fi

    log_info "Verifying backup integrity..."
    if ! tar -tzf "$backup_file" > /dev/null 2>&1; then
        log_error "Backup archive is corrupted"
        exit 1
    fi
    log_success "Backup file verified"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        return
    fi

    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker ${SUDO_USER:-pi}

    # Install docker-compose plugin
    apt-get update
    apt-get install -y docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    log_success "Docker installed"
}

mount_hdd() {
    if mountpoint -q /mnt/media; then
        log_info "HDD already mounted at /mnt/media"
        return
    fi

    log_warning "HDD not mounted. Attempting to mount..."

    # Try to find and mount the HDD
    local hdd_device=""

    # Look for ext4 partitions
    for device in /dev/sd*1; do
        if [[ -b "$device" ]]; then
            local fstype=$(blkid -s TYPE -o value "$device" 2>/dev/null)
            if [[ "$fstype" == "ext4" ]]; then
                hdd_device="$device"
                break
            fi
        fi
    done

    if [[ -z "$hdd_device" ]]; then
        log_error "Cannot find ext4 partition for HDD"
        log_info "Please mount your HDD manually:"
        echo "  sudo mount /dev/sdX1 /mnt/media"
        exit 1
    fi

    mkdir -p /mnt/media
    mount "$hdd_device" /mnt/media
    log_success "Mounted $hdd_device at /mnt/media"
}

extract_backup() {
    local backup_file="$1"
    local temp_dir="/tmp/mediahub_restore_$$"

    log_info "Extracting backup..."

    mkdir -p "$temp_dir"
    tar -xzf "$backup_file" -C "$temp_dir"

    # Find the extracted directory
    local backup_dir=$(ls -d "$temp_dir"/mediahub_backup_* 2>/dev/null | head -1)

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Invalid backup structure"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Show backup info
    if [[ -f "$backup_dir/backup_info.txt" ]]; then
        echo ""
        echo "========================================="
        echo "  Backup Information"
        echo "========================================="
        cat "$backup_dir/backup_info.txt"
        echo "========================================="
        echo ""
    fi

    echo "$backup_dir"
}

restore_configs() {
    local backup_dir="$1"

    log_info "Restoring configurations..."

    # Create target directory
    mkdir -p /opt/mediahub

    # Stop existing services if running
    if [[ -f /opt/mediahub/docker-compose.yml ]]; then
        log_info "Stopping existing services..."
        cd /opt/mediahub
        docker compose down 2>/dev/null || true
    fi

    # Restore config directory
    if [[ -d "$backup_dir/config" ]]; then
        log_info "Restoring service configurations..."
        mkdir -p /opt/mediahub/config
        rsync -a --delete "$backup_dir/config/" /opt/mediahub/config/
        log_success "Configurations restored"
    fi

    # Restore environment file
    if [[ -f "$backup_dir/.env" ]]; then
        log_info "Restoring environment file..."
        cp "$backup_dir/.env" /opt/mediahub/.env
        log_success "Environment file restored"
    else
        log_warning "No .env file in backup - you'll need to recreate it"
    fi

    # Restore docker-compose file
    if [[ -f "$backup_dir/docker-compose.yml" ]]; then
        log_info "Restoring docker-compose.yml..."
        cp "$backup_dir/docker-compose.yml" /opt/mediahub/docker-compose.yml
        log_success "Docker Compose file restored"
    fi

    # Restore scripts
    if [[ -d "$backup_dir/scripts" ]]; then
        log_info "Restoring scripts..."
        mkdir -p /opt/mediahub/scripts
        cp -r "$backup_dir/scripts/"* /opt/mediahub/scripts/
        chmod +x /opt/mediahub/scripts/*.sh
        log_success "Scripts restored"
    fi

    # Set ownership
    chown -R ${SUDO_USER:-1000}:${SUDO_USER:-1000} /opt/mediahub
}

create_helper_scripts() {
    log_info "Creating helper scripts..."

    # Start script
    cat > /opt/mediahub/start.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose up -d
echo "All services started"
docker compose ps
EOF

    # Stop script
    cat > /opt/mediahub/stop.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose down
echo "All services stopped"
EOF

    # Status script
    cat > /opt/mediahub/status.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose ps
EOF

    # Update script
    cat > /opt/mediahub/update.sh << 'EOF'
#!/bin/bash
cd /opt/mediahub
docker compose pull
docker compose down
docker compose up -d
docker image prune -f
echo "Update complete"
EOF

    chmod +x /opt/mediahub/*.sh
    log_success "Helper scripts created"
}

start_services() {
    log_info "Starting Docker services..."

    cd /opt/mediahub

    # Pull images first
    log_info "Pulling Docker images (this may take a while)..."
    docker compose pull 2>&1 | grep -E "Pulling|Downloaded|Pull complete" || true

    # Start services
    docker compose up -d

    log_success "Services started"
}

verify_restore() {
    log_info "Verifying restore..."

    cd /opt/mediahub

    local running=$(docker compose ps --status running --format json 2>/dev/null | jq -s length 2>/dev/null || docker compose ps | grep -c "Up")

    if [[ $running -gt 0 ]]; then
        log_success "$running services are running"
    else
        log_warning "No services running yet - they may still be starting"
    fi

    echo ""
    docker compose ps
}

setup_cron_backup() {
    log_info "Setting up automated daily backups..."

    # Create cron job for daily backup at 3 AM
    local cron_job="0 3 * * * /opt/mediahub/scripts/backup-config.sh --quick >> /var/log/mediahub-backup.log 2>&1"

    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "backup-config.sh"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        log_success "Daily backup scheduled at 3:00 AM"
    else
        log_info "Backup cron job already exists"
    fi
}

main() {
    if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    local backup_file="$1"

    echo "========================================="
    echo "  MediaHub Disaster Recovery"
    echo "========================================="
    echo ""

    check_root
    mount_hdd
    check_backup_file "$backup_file"

    echo ""
    read -p "This will restore MediaHub from backup. Continue? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        exit 0
    fi

    install_docker

    local backup_dir=$(extract_backup "$backup_file")

    restore_configs "$backup_dir"
    create_helper_scripts
    start_services
    setup_cron_backup
    verify_restore

    # Cleanup
    rm -rf "/tmp/mediahub_restore_$$"

    echo ""
    echo "========================================="
    log_success "RESTORE COMPLETE!"
    echo "========================================="
    echo ""
    echo "Your MediaHub is restored and running!"
    echo ""
    echo "Access your services:"
    echo "  Dashboard: http://$(hostname -I | awk '{print $1}'):7575"
    echo "  Jellyfin:  http://$(hostname -I | awk '{print $1}'):8096"
    echo ""
    echo "Important:"
    echo "  - Check all service configurations"
    echo "  - Verify API keys are still valid"
    echo "  - Test VPN connection: docker logs gluetun"
    echo ""
    echo "Daily backups are now scheduled at 3:00 AM"
    echo ""
}

main "$@"
