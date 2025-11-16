#!/bin/bash
# MediaHub Health Check Script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "  MediaHub Health Check"
echo "========================================="
echo ""

# Check Docker services
echo "=== Docker Services ==="
cd /opt/mediahub
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check VPN status
echo "=== VPN Status ==="
if docker ps | grep -q gluetun; then
    vpn_ip=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null)
    local_ip=$(hostname -I | awk '{print $1}')

    if [[ -n "$vpn_ip" && "$vpn_ip" != "$local_ip" ]]; then
        echo -e "${GREEN}VPN Active${NC} - External IP: $vpn_ip"
    else
        echo -e "${RED}VPN Issue${NC} - Check Gluetun logs"
    fi
else
    echo -e "${RED}Gluetun not running${NC}"
fi
echo ""

# System resources
echo "=== System Resources ==="
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print "  " $2 + $4 "%"}'

echo "Memory:"
free -h | awk '/^Mem:/ {print "  Used: " $3 "/" $2 " (" int($3/$2*100) "%)"}'

echo "Swap:"
free -h | awk '/^Swap:/ {print "  Used: " $3 "/" $2}'

echo "Temperature:"
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$((temp/1000))
    if [[ $temp_c -gt 70 ]]; then
        echo -e "  ${RED}${temp_c}°C - TOO HOT!${NC}"
    elif [[ $temp_c -gt 60 ]]; then
        echo -e "  ${YELLOW}${temp_c}°C - Getting warm${NC}"
    else
        echo -e "  ${GREEN}${temp_c}°C${NC}"
    fi
fi
echo ""

# Disk space
echo "=== Disk Space ==="
df -h /mnt/media | awk 'NR==2 {print "  Media: " $3 "/" $2 " (" $5 " used)"}'
df -h / | awk 'NR==2 {print "  System: " $3 "/" $2 " (" $5 " used)"}'

# Check if disk is getting full
media_usage=$(df /mnt/media | awk 'NR==2 {print int($5)}')
if [[ $media_usage -gt 90 ]]; then
    echo -e "  ${RED}WARNING: Media disk is ${media_usage}% full!${NC}"
elif [[ $media_usage -gt 80 ]]; then
    echo -e "  ${YELLOW}NOTICE: Media disk is ${media_usage}% full${NC}"
fi
echo ""

# External HDD health
echo "=== Storage Health ==="
if command -v smartctl &> /dev/null; then
    for disk in /dev/sd?; do
        if [[ -b "$disk" ]]; then
            health=$(sudo smartctl -H "$disk" 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}')
            if [[ "$health" == "PASSED" ]]; then
                echo -e "  $disk: ${GREEN}$health${NC}"
            else
                echo -e "  $disk: ${RED}$health${NC}"
            fi
        fi
    done
else
    echo "  smartctl not available"
fi
echo ""

# Network connectivity
echo "=== Network ==="
echo "  Local IP: $(hostname -I | awk '{print $1}')"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "  Internet: ${GREEN}Connected${NC}"
else
    echo -e "  Internet: ${RED}Disconnected${NC}"
fi

# Check service connectivity
echo ""
echo "=== Service Availability ==="
services=(
    "Jellyfin:8096"
    "Sonarr:8989"
    "Radarr:7878"
    "Prowlarr:9696"
    "qBittorrent:8080"
)

for service in "${services[@]}"; do
    name="${service%%:*}"
    port="${service##*:}"
    if curl -s --max-time 2 "http://localhost:$port" > /dev/null 2>&1; then
        echo -e "  $name: ${GREEN}Online${NC}"
    else
        echo -e "  $name: ${RED}Offline${NC}"
    fi
done
echo ""

# Recent errors
echo "=== Recent Issues (last 24h) ==="
docker compose logs --since 24h 2>&1 | grep -i "error\|fatal\|critical" | tail -5
if [[ $? -ne 0 ]]; then
    echo -e "  ${GREEN}No critical errors found${NC}"
fi
echo ""

echo "Health check complete!"
