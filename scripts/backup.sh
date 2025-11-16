#!/bin/bash
# MediaHub Backup Script

BACKUP_DIR="/mnt/media/backups"
CONFIG_DIR="/opt/mediahub/config"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mediahub_backup_$DATE"

echo "========================================="
echo "  MediaHub Backup"
echo "========================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Backing up configuration files..."

# Stop services to ensure consistent backup
read -p "Stop services during backup for consistency? (recommended) (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd /opt/mediahub
    docker compose down
    SERVICES_STOPPED=true
fi

# Create tarball of configs
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
    -C /opt/mediahub \
    --exclude='*/cache/*' \
    --exclude='*/logs/*' \
    --exclude='*/Logs/*' \
    --exclude='*/.cache/*' \
    config/ \
    .env \
    docker-compose.yml

echo "Backup created: $BACKUP_DIR/$BACKUP_NAME.tar.gz"

# Backup database files separately
echo "Backing up databases..."
for db in $CONFIG_DIR/*/**.db; do
    if [[ -f "$db" ]]; then
        cp "$db" "$BACKUP_DIR/${BACKUP_NAME}_$(basename $db)"
    fi
done

# Restart services if we stopped them
if [[ "$SERVICES_STOPPED" == true ]]; then
    echo "Restarting services..."
    docker compose up -d
fi

# Cleanup old backups (keep last 7)
echo "Cleaning up old backups..."
ls -t "$BACKUP_DIR"/mediahub_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

# Show backup info
echo ""
echo "Backup complete!"
echo "Location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo ""
echo "Total backup space used:"
du -sh "$BACKUP_DIR"
