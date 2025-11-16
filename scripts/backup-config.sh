#!/bin/bash
# Automated backup of MediaHub configurations to external HDD
# Run daily via cron to protect against SD card failure

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONFIG_SOURCE="/opt/mediahub/config"
BACKUP_DEST="/mnt/media/backups/mediahub"
ENV_FILE="/opt/mediahub/.env"
COMPOSE_FILE="/opt/mediahub/docker-compose.yml"
RETENTION_DAYS=7
MAX_BACKUPS=10
LOG_FILE="/var/log/mediahub-backup.log"

log_info() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

check_prerequisites() {
    # Check if HDD is mounted
    if ! mountpoint -q /mnt/media; then
        log_error "External HDD not mounted at /mnt/media"
        exit 1
    fi

    # Check if source exists
    if [[ ! -d "$CONFIG_SOURCE" ]]; then
        log_error "Config directory $CONFIG_SOURCE does not exist"
        exit 1
    fi

    # Create backup directory if needed
    mkdir -p "$BACKUP_DEST"

    # Create log file if needed
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/mediahub-backup.log"
}

stop_services() {
    log_info "Stopping Docker services for consistent backup..."
    cd /opt/mediahub
    docker compose stop 2>/dev/null || true
    sleep 5
}

start_services() {
    log_info "Restarting Docker services..."
    cd /opt/mediahub
    docker compose start 2>/dev/null || docker compose up -d
}

create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="mediahub_backup_${timestamp}"
    local backup_path="${BACKUP_DEST}/${backup_name}"

    log_info "Creating backup: $backup_name"

    mkdir -p "$backup_path"

    # Backup configurations
    log_info "Backing up service configurations..."
    rsync -a --info=progress2 "$CONFIG_SOURCE/" "$backup_path/config/" 2>&1 | tee -a "$LOG_FILE"

    # Backup environment file
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Backing up environment file..."
        cp "$ENV_FILE" "$backup_path/.env"
    fi

    # Backup docker-compose file
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_info "Backing up docker-compose.yml..."
        cp "$COMPOSE_FILE" "$backup_path/docker-compose.yml"
    fi

    # Backup scripts
    if [[ -d "/opt/mediahub/scripts" ]]; then
        log_info "Backing up scripts..."
        cp -r /opt/mediahub/scripts "$backup_path/scripts/"
    fi

    # Create metadata file
    cat > "$backup_path/backup_info.txt" << EOF
MediaHub Backup
===============
Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
Raspberry Pi Model: $(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Docker Version: $(docker --version 2>/dev/null || echo "Not installed")
Total Containers: $(docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l)

Services Backed Up:
$(ls -1 "$backup_path/config/" 2>/dev/null | sed 's/^/  - /')

Backup Size: $(du -sh "$backup_path" | cut -f1)
EOF

    # Compress the backup
    log_info "Compressing backup..."
    cd "$BACKUP_DEST"
    tar -czf "${backup_name}.tar.gz" "$backup_name" 2>&1 | tee -a "$LOG_FILE"
    rm -rf "$backup_path"

    local final_size=$(du -sh "${BACKUP_DEST}/${backup_name}.tar.gz" | cut -f1)
    log_success "Backup created: ${backup_name}.tar.gz (${final_size})"

    echo "${backup_name}.tar.gz"
}

cleanup_old_backups() {
    log_info "Cleaning up old backups (keeping last $MAX_BACKUPS)..."

    cd "$BACKUP_DEST"

    # Count current backups
    local backup_count=$(ls -1 mediahub_backup_*.tar.gz 2>/dev/null | wc -l)

    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        local to_delete=$((backup_count - MAX_BACKUPS))
        log_info "Removing $to_delete old backup(s)..."

        # Delete oldest backups
        ls -1t mediahub_backup_*.tar.gz | tail -n "$to_delete" | while read backup; do
            log_info "Deleting: $backup"
            rm -f "$backup"
        done
    fi

    # Also remove backups older than retention period
    find "$BACKUP_DEST" -name "mediahub_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

    log_success "Cleanup complete"
}

verify_backup() {
    local backup_file="$1"

    log_info "Verifying backup integrity..."

    if tar -tzf "${BACKUP_DEST}/${backup_file}" > /dev/null 2>&1; then
        log_success "Backup verification passed"
        return 0
    else
        log_error "Backup verification FAILED - archive may be corrupted"
        return 1
    fi
}

show_backup_status() {
    echo ""
    echo "========================================="
    echo "  MediaHub Backup Status"
    echo "========================================="
    echo ""

    if [[ -d "$BACKUP_DEST" ]]; then
        echo "Backup location: $BACKUP_DEST"
        echo "Available backups:"
        ls -lh "$BACKUP_DEST"/mediahub_backup_*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
        echo ""
        echo "Total backup size: $(du -sh "$BACKUP_DEST" 2>/dev/null | cut -f1)"
        echo "Free space on HDD: $(df -h /mnt/media | awk 'NR==2 {print $4}')"
    else
        echo "No backups found"
    fi
    echo ""
}

main() {
    local quick_mode=false
    local status_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick_mode=true
                shift
                ;;
            --status)
                status_only=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --quick    Quick backup without stopping services (less consistent)"
                echo "  --status   Show backup status only"
                echo "  --help     Show this help"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$status_only" == true ]]; then
        show_backup_status
        exit 0
    fi

    echo "========================================="
    echo "  MediaHub Configuration Backup"
    echo "========================================="
    echo ""

    check_prerequisites

    if [[ "$quick_mode" == false ]]; then
        stop_services
    else
        log_warning "Quick mode: Services remain running (backup may be inconsistent)"
    fi

    local backup_file=$(create_backup)

    if [[ "$quick_mode" == false ]]; then
        start_services
    fi

    verify_backup "$backup_file"
    cleanup_old_backups

    echo ""
    log_success "Backup complete!"
    echo ""
    echo "Restore command:"
    echo "  sudo ./scripts/restore-config.sh ${BACKUP_DEST}/${backup_file}"
    echo ""

    show_backup_status
}

main "$@"
