#!/bin/bash
# Show status of all MediaHub services
# This script is copied to /opt/mediahub/status.sh during installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR%/scripts}"

# If running from /opt/mediahub
if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    cd "$INSTALL_DIR"
elif [[ -f "/opt/mediahub/docker-compose.yml" ]]; then
    cd /opt/mediahub
else
    echo "Error: Cannot find docker-compose.yml"
    exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  MediaHub Status${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# System info
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Uptime: $(uptime -p)"

# CPU temperature (Raspberry Pi)
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    if [[ $temp -gt 70 ]]; then
        echo -e "CPU Temp: ${RED}${temp}°C (HOT!)${NC}"
    elif [[ $temp -gt 60 ]]; then
        echo -e "CPU Temp: ${YELLOW}${temp}°C (Warm)${NC}"
    else
        echo -e "CPU Temp: ${GREEN}${temp}°C (Good)${NC}"
    fi
fi

# Memory usage
mem_info=$(free -h | awk 'NR==2 {print $3 "/" $2 " (" int($3/$2*100) "%)"}')
echo "Memory: $mem_info"

# Disk usage
echo ""
echo "=== Storage ==="
df -h / | awk 'NR==2 {print "SD Card: " $3 "/" $2 " (" $5 " used)"}'
if mountpoint -q /mnt/media 2>/dev/null; then
    df -h /mnt/media | awk 'NR==2 {print "HDD:     " $3 "/" $2 " (" $5 " used)"}'
else
    echo -e "HDD:     ${RED}NOT MOUNTED${NC}"
fi

# Docker status
echo ""
echo "=== Docker Services ==="
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not installed${NC}"
    exit 1
fi

# Count services
total=$(docker compose ps --format json 2>/dev/null | jq -s length 2>/dev/null || docker compose config --services | wc -l)
running=$(docker compose ps --status running --format json 2>/dev/null | jq -s length 2>/dev/null || docker compose ps | grep -c "Up" || echo "0")
stopped=$((total - running))

echo -e "Total: $total | Running: ${GREEN}$running${NC} | Stopped: ${RED}$stopped${NC}"
echo ""

# List services with status
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -35 || docker compose ps

# VPN Status
echo ""
echo "=== VPN Status ==="
vpn_status=$(docker inspect gluetun --format '{{.State.Status}}' 2>/dev/null || echo "not found")
if [[ "$vpn_status" == "running" ]]; then
    echo -e "Gluetun: ${GREEN}Running${NC}"
    vpn_ip=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "FAILED")
    if [[ "$vpn_ip" != "FAILED" ]] && [[ -n "$vpn_ip" ]]; then
        vpn_country=$(docker exec gluetun wget -qO- https://ipinfo.io/country 2>/dev/null || echo "Unknown")
        echo -e "VPN IP: ${GREEN}$vpn_ip ($vpn_country)${NC}"
    else
        echo -e "VPN IP: ${RED}Not connected${NC}"
    fi
else
    echo -e "Gluetun: ${RED}$vpn_status${NC}"
fi

# Recent errors
echo ""
echo "=== Recent Issues ==="
errors=$(docker compose logs --tail=100 2>&1 | grep -i "error\|failed\|fatal" | tail -5)
if [[ -n "$errors" ]]; then
    echo -e "${YELLOW}Recent errors found:${NC}"
    echo "$errors" | head -5
else
    echo -e "${GREEN}No recent errors${NC}"
fi

# Backup status
echo ""
echo "=== Backup Status ==="
if [[ -d "/mnt/media/backups/mediahub" ]]; then
    latest_backup=$(ls -t /mnt/media/backups/mediahub/*.tar.gz 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        backup_date=$(stat -c %y "$latest_backup" | cut -d' ' -f1)
        backup_size=$(du -sh "$latest_backup" | cut -f1)
        echo -e "Latest: ${GREEN}$backup_date ($backup_size)${NC}"
    else
        echo -e "${YELLOW}No backups found${NC}"
    fi
else
    echo -e "${RED}Backup directory not found${NC}"
fi

# Quick links
echo ""
echo "=== Quick Access ==="
local_ip=$(hostname -I | awk '{print $1}')
echo "Dashboard:  http://$local_ip:7575"
echo "Jellyfin:   http://$local_ip:8096"
echo "Sonarr:     http://$local_ip:8989"
echo "Radarr:     http://$local_ip:7878"
echo "qBittorrent: http://$local_ip:8080"
echo ""
echo "Run './health-check.sh' for detailed diagnostics"
