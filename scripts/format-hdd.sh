#!/bin/bash
# Format external HDD for MediaHub
# WARNING: This will ERASE all data on the selected drive!

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

show_drives() {
    echo "========================================="
    echo "  External HDD Formatting Tool"
    echo "  For Toshiba Canvio Partner 2TB"
    echo "========================================="
    echo ""
    log_warning "This will ERASE ALL DATA on the selected drive!"
    echo ""

    echo "Available drives:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "sd|nvme"
    echo ""
}

select_drive() {
    read -p "Enter drive name (e.g., sda, NOT sda1): " drive_name

    if [[ ! -b "/dev/$drive_name" ]]; then
        log_error "Drive /dev/$drive_name does not exist"
        exit 1
    fi

    # Check if it's the system drive
    if mount | grep -q "^/dev/${drive_name}"; then
        log_error "This appears to be a mounted system drive. Aborting."
        exit 1
    fi

    DRIVE="/dev/$drive_name"

    echo ""
    log_warning "You selected: $DRIVE"
    lsblk "$DRIVE" -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINT
    echo ""

    read -p "Are you ABSOLUTELY SURE you want to erase this drive? Type 'YES' to confirm: " confirm
    if [[ "$confirm" != "YES" ]]; then
        log_info "Aborted."
        exit 0
    fi
}

unmount_drive() {
    log_info "Unmounting any partitions..."
    for partition in $(lsblk -ln "$DRIVE" -o NAME | tail -n +2); do
        if mount | grep -q "/dev/$partition"; then
            umount "/dev/$partition" 2>/dev/null || true
        fi
    done
}

format_drive() {
    log_info "Creating new partition table..."

    # Create GPT partition table
    parted -s "$DRIVE" mklabel gpt

    # Create single partition using all space
    parted -s "$DRIVE" mkpart primary ext4 0% 100%

    # Wait for partition to be recognized
    sleep 2
    partprobe "$DRIVE"
    sleep 2

    # Get partition name (sda1 or nvme0n1p1)
    if [[ "$DRIVE" =~ nvme ]]; then
        PARTITION="${DRIVE}p1"
    else
        PARTITION="${DRIVE}1"
    fi

    log_info "Formatting partition as ext4..."
    mkfs.ext4 -L "MediaHub" "$PARTITION"

    log_success "Drive formatted successfully!"
    echo ""

    # Show result
    lsblk "$DRIVE" -o NAME,SIZE,FSTYPE,LABEL
}

setup_mount() {
    local mount_point="/mnt/media"

    log_info "Setting up mount point..."

    # Create mount point
    mkdir -p "$mount_point"

    # Mount the drive
    mount "$PARTITION" "$mount_point"

    # Get UUID
    local uuid=$(blkid -s UUID -o value "$PARTITION")

    # Add to fstab if not already there
    if ! grep -q "$uuid" /etc/fstab; then
        log_info "Adding to /etc/fstab for auto-mount..."
        echo "UUID=$uuid $mount_point ext4 defaults,nofail,x-systemd.device-timeout=30 0 2" >> /etc/fstab
    fi

    # Set ownership
    chown -R ${SUDO_USER:-1000}:${SUDO_USER:-1000} "$mount_point"

    log_success "Drive mounted at $mount_point"
}

create_directories() {
    log_info "Creating MediaHub directory structure..."

    local mount_point="/mnt/media"

    mkdir -p "$mount_point"/{downloads,library,backups,recordings}
    mkdir -p "$mount_point"/downloads/{complete,incomplete}
    mkdir -p "$mount_point"/library/{movies,tv,music,books,photos,comics}
    mkdir -p "$mount_point"/library/photos/{originals,import}
    mkdir -p "$mount_point"/library/comics/{series,oneshots}

    # Set permissions
    chown -R ${SUDO_USER:-1000}:${SUDO_USER:-1000} "$mount_point"
    chmod -R 755 "$mount_point"

    log_success "Directory structure created!"
    echo ""
    tree -L 2 "$mount_point" 2>/dev/null || ls -la "$mount_point"
}

show_summary() {
    echo ""
    echo "========================================="
    log_success "HDD Setup Complete!"
    echo "========================================="
    echo ""
    echo "Drive: $DRIVE"
    echo "Partition: $PARTITION"
    echo "Mount point: /mnt/media"
    echo "Filesystem: ext4"
    echo ""
    echo "Total space:"
    df -h /mnt/media | awk 'NR==2 {print "  Size: " $2 "\n  Available: " $4}'
    echo ""
    echo "Directory structure:"
    echo "  /mnt/media/downloads/     - Téléchargements"
    echo "  /mnt/media/library/       - Bibliothèque médias"
    echo "  /mnt/media/backups/       - Sauvegardes"
    echo "  /mnt/media/recordings/    - Enregistrements TV"
    echo ""
    log_info "The drive will auto-mount on boot"
}

optimize_for_media() {
    log_info "Optimizing drive for media storage..."

    # Disable access time updates (reduces writes)
    if ! grep -q "noatime" /etc/fstab | grep "$PARTITION"; then
        sed -i "s|$PARTITION.*defaults|$PARTITION defaults,noatime|" /etc/fstab
    fi

    # Set scheduler for HDD
    local drive_name=$(basename "$DRIVE")
    echo "deadline" > /sys/block/$drive_name/queue/scheduler 2>/dev/null || true

    log_success "Drive optimized"
}

main() {
    check_root
    show_drives
    select_drive
    unmount_drive
    format_drive
    setup_mount
    create_directories
    optimize_for_media
    show_summary
}

main "$@"
