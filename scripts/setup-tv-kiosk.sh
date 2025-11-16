#!/bin/bash
# Setup TV Kiosk Mode for MediaHub Dashboard
# Displays Homarr dashboard on TV connected via HDMI

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

DASHBOARD_URL="http://localhost:7575"  # Homarr
KIOSK_USER="${SUDO_USER:-pi}"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

install_dependencies() {
    log_info "Installing kiosk mode dependencies..."

    apt-get update
    apt-get install -y \
        chromium-browser \
        xserver-xorg \
        x11-xserver-utils \
        xinit \
        openbox \
        unclutter

    log_success "Dependencies installed"
}

configure_autologin() {
    log_info "Configuring auto-login for kiosk user..."

    # Configure auto-login on tty1
    mkdir -p /etc/systemd/system/getty@tty1.service.d/

    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

    systemctl daemon-reload

    log_success "Auto-login configured for $KIOSK_USER"
}

setup_openbox() {
    log_info "Configuring Openbox window manager..."

    local user_home=$(eval echo ~$KIOSK_USER)

    mkdir -p "$user_home/.config/openbox"

    # Openbox autostart - launches Chromium in kiosk mode
    cat > "$user_home/.config/openbox/autostart" << EOF
# Disable screen saver and power management
xset s off
xset s noblank
xset -dpms

# Hide mouse cursor after 5 seconds of inactivity
unclutter -idle 5 -root &

# Wait for network and services
sleep 10

# Launch Chromium in kiosk mode
chromium-browser \\
    --kiosk \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-restore-session-state \\
    --disable-features=TranslateUI \\
    --noerrdialogs \\
    --no-first-run \\
    --start-fullscreen \\
    --window-position=0,0 \\
    --user-data-dir=/tmp/chromium-kiosk \\
    "$DASHBOARD_URL"
EOF

    chown -R "$KIOSK_USER:$KIOSK_USER" "$user_home/.config/openbox"

    log_success "Openbox configured"
}

setup_xinit() {
    log_info "Configuring X server startup..."

    local user_home=$(eval echo ~$KIOSK_USER)

    # Create .xinitrc to start openbox
    cat > "$user_home/.xinitrc" << 'EOF'
#!/bin/sh

# Set screen resolution (adjust if needed)
# xrandr --output HDMI-1 --mode 1920x1080 --rate 60

# Start Openbox
exec openbox-session
EOF

    chmod +x "$user_home/.xinitrc"
    chown "$KIOSK_USER:$KIOSK_USER" "$user_home/.xinitrc"

    log_success "X server configured"
}

setup_auto_startx() {
    log_info "Configuring automatic X server start..."

    local user_home=$(eval echo ~$KIOSK_USER)

    # Add startx to .bash_profile
    if ! grep -q "startx" "$user_home/.bash_profile" 2>/dev/null; then
        cat >> "$user_home/.bash_profile" << 'EOF'

# Start X server on login (tty1 only)
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    exec startx -- -nocursor
fi
EOF
    fi

    chown "$KIOSK_USER:$KIOSK_USER" "$user_home/.bash_profile"

    log_success "Auto-start X configured"
}

create_dashboard_launcher() {
    log_info "Creating dashboard launcher scripts..."

    # Script to change dashboard URL
    cat > /opt/mediahub/scripts/change-dashboard.sh << 'EOF'
#!/bin/bash
# Change the dashboard URL displayed on TV

CURRENT_URL=$(grep "chromium-browser" ~/.config/openbox/autostart | grep -oP 'http[s]?://[^ ]+' | tail -1)

echo "Current dashboard: $CURRENT_URL"
echo ""
echo "Available options:"
echo "  1. Homarr (Dashboard)     - http://localhost:7575"
echo "  2. Jellyfin (Media)       - http://localhost:8096"
echo "  3. Komga (Comics)         - http://localhost:25600"
echo "  4. Navidrome (Music)      - http://localhost:4533"
echo "  5. TV Admin Panel         - http://localhost:8091"
echo "  6. Uptime Kuma (Status)   - http://localhost:3001"
echo "  7. Custom URL"
echo ""
read -p "Select option (1-7): " choice

case $choice in
    1) NEW_URL="http://localhost:7575" ;;
    2) NEW_URL="http://localhost:8096" ;;
    3) NEW_URL="http://localhost:25600" ;;
    4) NEW_URL="http://localhost:4533" ;;
    5) NEW_URL="http://localhost:8091" ;;
    6) NEW_URL="http://localhost:3001" ;;
    7)
        read -p "Enter custom URL: " NEW_URL
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

sed -i "s|$CURRENT_URL|$NEW_URL|g" ~/.config/openbox/autostart
echo "Dashboard URL changed to: $NEW_URL"
echo "Restart X to apply: sudo systemctl restart mediahub-kiosk"
EOF

    chmod +x /opt/mediahub/scripts/change-dashboard.sh
    chown "$KIOSK_USER:$KIOSK_USER" /opt/mediahub/scripts/change-dashboard.sh

    # Script to refresh dashboard
    cat > /opt/mediahub/scripts/refresh-dashboard.sh << 'EOF'
#!/bin/bash
# Refresh the TV dashboard by restarting Chromium

pkill -f chromium-browser
sleep 2
# Chromium will be restarted by openbox autostart
EOF

    chmod +x /opt/mediahub/scripts/refresh-dashboard.sh

    log_success "Dashboard launchers created"
}

create_kiosk_service() {
    log_info "Creating kiosk systemd service..."

    cat > /etc/systemd/system/mediahub-kiosk.service << EOF
[Unit]
Description=MediaHub TV Kiosk Mode
After=mediahub.service network-online.target
Wants=mediahub.service

[Service]
Type=simple
User=$KIOSK_USER
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 15
ExecStart=/usr/bin/startx -- -nocursor
Restart=on-failure
RestartSec=10
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes

[Install]
WantedBy=graphical.target
EOF

    systemctl daemon-reload
    systemctl enable mediahub-kiosk.service

    log_success "Kiosk service created"
}

configure_hdmi_output() {
    log_info "Configuring HDMI output..."

    # Enable HDMI hotplug
    if ! grep -q "hdmi_force_hotplug" /boot/config.txt; then
        cat >> /boot/config.txt << 'EOF'

# MediaHub TV Configuration
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
EOF
        log_info "HDMI hotplug enabled (requires reboot)"
    fi

    log_success "HDMI configured"
}

print_summary() {
    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "========================================="
    log_success "TV Kiosk Mode Setup Complete!"
    echo "========================================="
    echo ""
    echo "Configuration:"
    echo "  User: $KIOSK_USER"
    echo "  Dashboard URL: $DASHBOARD_URL"
    echo "  Auto-start: Enabled"
    echo ""
    echo "Controls:"
    echo "  - TV remote controls via HDMI-CEC"
    echo "  - Mouse cursor hidden after 5 seconds"
    echo "  - Screen saver disabled"
    echo ""
    echo "Management commands:"
    echo "  Restart kiosk: sudo systemctl restart mediahub-kiosk"
    echo "  Stop kiosk: sudo systemctl stop mediahub-kiosk"
    echo "  Change dashboard: /opt/mediahub/scripts/change-dashboard.sh"
    echo "  Refresh display: /opt/mediahub/scripts/refresh-dashboard.sh"
    echo ""
    echo "Dashboard URLs:"
    echo "  Homarr:    http://$ip:7575"
    echo "  Jellyfin:  http://$ip:8096"
    echo "  Komga:     http://$ip:25600"
    echo "  Navidrome: http://$ip:4533"
    echo ""
    log_warning "Please reboot to activate kiosk mode: sudo reboot"
    echo ""
}

main() {
    echo "========================================="
    echo "  MediaHub TV Kiosk Setup"
    echo "========================================="
    echo ""

    check_root

    read -p "This will setup TV kiosk mode. Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    install_dependencies
    configure_autologin
    setup_openbox
    setup_xinit
    setup_auto_startx
    create_dashboard_launcher
    create_kiosk_service
    configure_hdmi_output

    print_summary
}

main "$@"
