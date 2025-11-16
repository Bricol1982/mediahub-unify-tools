#!/bin/bash
# MediaHub System Alerts
# Monitors system health and sends notifications for critical events
# Run via cron: */15 * * * * /opt/mediahub/scripts/system-alerts.sh

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
SCRIPT_DIR="$(dirname "$0")"
ALERT_STATE_FILE="/tmp/mediahub_alert_state"

# Load notification helper
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-normal}"

    if [[ -f "$INSTALL_DIR/scripts/notify.sh" ]]; then
        "$INSTALL_DIR/scripts/notify.sh" "$title" "$message" "$priority"
    fi
}

# Check if alert was already sent (avoid spam)
alert_sent() {
    local alert_key="$1"
    grep -q "^$alert_key$" "$ALERT_STATE_FILE" 2>/dev/null
}

mark_alert_sent() {
    local alert_key="$1"
    echo "$alert_key" >> "$ALERT_STATE_FILE"
}

clear_alert() {
    local alert_key="$1"
    sed -i "/^$alert_key$/d" "$ALERT_STATE_FILE" 2>/dev/null || true
}

# Initialize state file if needed
touch "$ALERT_STATE_FILE"

# ===========================================
# Check VPN Status
# ===========================================
check_vpn() {
    if docker ps | grep -q gluetun; then
        vpn_ip=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null)
        local_ip=$(hostname -I | awk '{print $1}')

        if [[ -z "$vpn_ip" ]] || [[ "$vpn_ip" == "$local_ip" ]]; then
            if ! alert_sent "vpn_down"; then
                notify "🚨 VPN DISCONNECTED" "VPN is not working! Your IP may be exposed. Check Gluetun container immediately." "urgent"
                mark_alert_sent "vpn_down"
            fi
        else
            if alert_sent "vpn_down"; then
                notify "✅ VPN Reconnected" "VPN is working again. Current IP: $vpn_ip" "normal"
                clear_alert "vpn_down"
            fi
        fi
    else
        if ! alert_sent "gluetun_stopped"; then
            notify "🚨 Gluetun Container Stopped" "VPN container is not running! Torrent traffic is unprotected." "urgent"
            mark_alert_sent "gluetun_stopped"
        fi
    fi
}

# ===========================================
# Check Disk Space
# ===========================================
check_disk_space() {
    # Check media disk
    if mountpoint -q /mnt/media 2>/dev/null; then
        usage=$(df /mnt/media | awk 'NR==2 {print int($5)}')

        if [[ $usage -gt 95 ]]; then
            if ! alert_sent "disk_critical"; then
                notify "🚨 DISK CRITICAL" "Media disk is ${usage}% full! Downloads may fail. Free up space immediately." "urgent"
                mark_alert_sent "disk_critical"
            fi
        elif [[ $usage -gt 90 ]]; then
            if ! alert_sent "disk_warning"; then
                notify "⚠️ Disk Space Warning" "Media disk is ${usage}% full. Consider freeing up space." "high"
                mark_alert_sent "disk_warning"
            fi
        else
            clear_alert "disk_warning"
            clear_alert "disk_critical"
        fi
    else
        if ! alert_sent "hdd_unmounted"; then
            notify "🚨 HDD NOT MOUNTED" "External HDD is not mounted at /mnt/media! Check USB connection." "urgent"
            mark_alert_sent "hdd_unmounted"
        fi
    fi

    # Check system disk
    sys_usage=$(df / | awk 'NR==2 {print int($5)}')
    if [[ $sys_usage -gt 85 ]]; then
        if ! alert_sent "system_disk_warning"; then
            notify "⚠️ System Disk Warning" "SD card is ${sys_usage}% full. Clean up logs or old images." "high"
            mark_alert_sent "system_disk_warning"
        fi
    else
        clear_alert "system_disk_warning"
    fi
}

# ===========================================
# Check Temperature (Raspberry Pi)
# ===========================================
check_temperature() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))

        if [[ $temp -gt 80 ]]; then
            if ! alert_sent "temp_critical"; then
                notify "🔥 CRITICAL TEMPERATURE" "CPU temperature is ${temp}°C! System may throttle or shut down. Improve cooling!" "urgent"
                mark_alert_sent "temp_critical"
            fi
        elif [[ $temp -gt 70 ]]; then
            if ! alert_sent "temp_warning"; then
                notify "🌡️ High Temperature" "CPU temperature is ${temp}°C. Consider improving ventilation." "high"
                mark_alert_sent "temp_warning"
            fi
        else
            clear_alert "temp_warning"
            clear_alert "temp_critical"
        fi
    fi
}

# ===========================================
# Check Critical Services
# ===========================================
check_services() {
    cd "$INSTALL_DIR" 2>/dev/null || return

    # List of critical services
    critical_services=("jellyfin" "sonarr" "radarr" "qbittorrent")

    for service in "${critical_services[@]}"; do
        status=$(docker inspect "$service" --format '{{.State.Status}}' 2>/dev/null || echo "not found")

        if [[ "$status" != "running" ]]; then
            if ! alert_sent "service_${service}_down"; then
                notify "🛑 Service Down" "$service is not running (status: $status). Check with: docker logs $service" "high"
                mark_alert_sent "service_${service}_down"
            fi
        else
            if alert_sent "service_${service}_down"; then
                notify "✅ Service Recovered" "$service is running again." "normal"
                clear_alert "service_${service}_down"
            fi
        fi
    done
}

# ===========================================
# Check Memory Usage
# ===========================================
check_memory() {
    mem_percent=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')

    if [[ $mem_percent -gt 90 ]]; then
        if ! alert_sent "memory_critical"; then
            notify "⚠️ High Memory Usage" "RAM usage is at ${mem_percent}%. System may become unresponsive." "high"
            mark_alert_sent "memory_critical"
        fi
    else
        clear_alert "memory_critical"
    fi
}

# ===========================================
# Check Internet Connectivity
# ===========================================
check_internet() {
    if ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        if ! alert_sent "internet_down"; then
            notify "🌐 Internet Disconnected" "No internet connectivity. Check your network connection." "high"
            mark_alert_sent "internet_down"
        fi
    else
        if alert_sent "internet_down"; then
            notify "✅ Internet Restored" "Internet connectivity is back online." "normal"
            clear_alert "internet_down"
        fi
    fi
}

# ===========================================
# Check Failed Docker Containers
# ===========================================
check_failed_containers() {
    cd "$INSTALL_DIR" 2>/dev/null || return

    # Check for containers in error/exit state
    failed=$(docker compose ps --filter "status=exited" --filter "status=dead" -q 2>/dev/null | wc -l)

    if [[ $failed -gt 0 ]]; then
        if ! alert_sent "containers_failed"; then
            failed_names=$(docker compose ps --filter "status=exited" --filter "status=dead" --format "{{.Name}}" 2>/dev/null | head -5 | tr '\n' ', ')
            notify "🛑 Container(s) Failed" "$failed container(s) stopped unexpectedly: ${failed_names%,}" "high"
            mark_alert_sent "containers_failed"
        fi
    else
        clear_alert "containers_failed"
    fi
}

# ===========================================
# Check Backup Status
# ===========================================
check_backup_age() {
    backup_dir="/mnt/media/backups/mediahub"

    if [[ -d "$backup_dir" ]]; then
        latest=$(ls -t "$backup_dir"/*.tar.gz 2>/dev/null | head -1)

        if [[ -n "$latest" ]]; then
            # Check if backup is older than 48 hours
            age_hours=$(( ($(date +%s) - $(stat -c %Y "$latest")) / 3600 ))

            if [[ $age_hours -gt 48 ]]; then
                if ! alert_sent "backup_old"; then
                    notify "⚠️ Backup Overdue" "Last backup is ${age_hours} hours old. Check backup cron job." "normal"
                    mark_alert_sent "backup_old"
                fi
            else
                clear_alert "backup_old"
            fi
        fi
    fi
}

# ===========================================
# Run All Checks
# ===========================================
main() {
    check_internet
    check_vpn
    check_disk_space
    check_temperature
    check_memory
    check_services
    check_failed_containers
    check_backup_age
}

# Run main function
main

# Clean old alerts (older than 24h)
find "$ALERT_STATE_FILE" -mtime +1 -delete 2>/dev/null || true
