#!/bin/bash
# Change the TV kiosk display dashboard

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
KIOSK_SERVICE="mediahub-kiosk"

echo "========================================="
echo "  MediaHub TV Dashboard Selector"
echo "========================================="
echo ""
echo "Available dashboards:"
echo "  1) Homarr (Home Dashboard)"
echo "  2) Jellyfin (Media Player)"
echo "  3) Komga (Comics/Manga)"
echo "  4) Navidrome (Music)"
echo "  5) TV Admin Panel"
echo ""
read -p "Select dashboard [1-5]: " choice

case $choice in
    1)
        URL="http://localhost:7575"
        NAME="Homarr"
        ;;
    2)
        URL="http://localhost:8096"
        NAME="Jellyfin"
        ;;
    3)
        URL="http://localhost:25600"
        NAME="Komga"
        ;;
    4)
        URL="http://localhost:4533"
        NAME="Navidrome"
        ;;
    5)
        URL="http://localhost:8091"
        NAME="TV Admin Panel"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Switching to $NAME..."

# Update kiosk configuration
if [[ -f "/home/pi/.config/openbox/autostart" ]]; then
    sudo sed -i "s|chromium-browser.*|chromium-browser --kiosk --noerrdialogs --disable-infobars --incognito $URL \&|" /home/pi/.config/openbox/autostart
    echo "Updated autostart configuration"
fi

# Restart kiosk if running
if systemctl is-active --quiet $KIOSK_SERVICE 2>/dev/null; then
    echo "Restarting kiosk service..."
    sudo systemctl restart $KIOSK_SERVICE
else
    echo "Kiosk service not running. Changes will apply on next start."
fi

echo ""
echo "✓ Dashboard changed to $NAME"
echo "  URL: $URL"
