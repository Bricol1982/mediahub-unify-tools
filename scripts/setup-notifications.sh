#!/bin/bash
# MediaHub Notification Configuration Script
# Sets up SMTP and push notification services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"
CONFIG_DIR="$INSTALL_DIR/config"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  MediaHub Notification Setup${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if running from correct directory
if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    if [[ -f "./docker-compose.yml" ]]; then
        INSTALL_DIR="$(pwd)"
        CONFIG_DIR="$INSTALL_DIR/config"
    else
        echo -e "${RED}Error: Cannot find docker-compose.yml${NC}"
        echo "Please run from /opt/mediahub or the project directory"
        exit 1
    fi
fi

# Create notification config directories
mkdir -p "$CONFIG_DIR"/{mailrise,gotify,apprise,ntfy}

echo "MediaHub can send you notifications for:"
echo "  - Download completed (Sonarr/Radarr/Lidarr)"
echo "  - New episodes/movies available"
echo "  - System health alerts (disk full, VPN down)"
echo "  - Backup status"
echo "  - Container updates (Watchtower)"
echo ""

echo "Available notification methods:"
echo "  1) Discord (webhook)"
echo "  2) Telegram (bot)"
echo "  3) Gotify (self-hosted push - recommended)"
echo "  4) ntfy (self-hosted push)"
echo "  5) Email (external SMTP)"
echo "  6) All of the above"
echo ""

read -p "Choose notification method(s) [3]: " notify_method
notify_method=${notify_method:-3}

# Initialize notification URLs array
NOTIFICATION_URLS=""

# Configure Discord
configure_discord() {
    echo ""
    echo -e "${BLUE}=== Discord Configuration ===${NC}"
    echo "To create a Discord webhook:"
    echo "1. Open Discord and go to your server"
    echo "2. Server Settings > Integrations > Webhooks"
    echo "3. New Webhook > Copy Webhook URL"
    echo ""

    read -p "Enter Discord Webhook URL: " discord_url

    if [[ -n "$discord_url" ]]; then
        # Extract webhook ID and token from URL
        # Format: https://discord.com/api/webhooks/ID/TOKEN
        if [[ "$discord_url" =~ webhooks/([0-9]+)/([a-zA-Z0-9_-]+) ]]; then
            DISCORD_ID="${BASH_REMATCH[1]}"
            DISCORD_TOKEN="${BASH_REMATCH[2]}"

            # Update .env
            sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=$discord_url|" "$INSTALL_DIR/.env"

            NOTIFICATION_URLS="$NOTIFICATION_URLS discord://$DISCORD_ID/$DISCORD_TOKEN"
            echo -e "${GREEN}Discord configured!${NC}"
        else
            echo -e "${RED}Invalid Discord webhook URL${NC}"
        fi
    fi
}

# Configure Telegram
configure_telegram() {
    echo ""
    echo -e "${BLUE}=== Telegram Configuration ===${NC}"
    echo "To create a Telegram bot:"
    echo "1. Open Telegram and search for @BotFather"
    echo "2. Send /newbot and follow instructions"
    echo "3. Copy the bot token"
    echo ""
    echo "To get your Chat ID:"
    echo "1. Start a chat with your bot"
    echo "2. Send any message"
    echo "3. Visit: https://api.telegram.org/bot<TOKEN>/getUpdates"
    echo "4. Find 'chat':{'id': YOUR_ID}"
    echo ""

    read -p "Enter Telegram Bot Token: " tg_token
    read -p "Enter Telegram Chat ID: " tg_chat

    if [[ -n "$tg_token" && -n "$tg_chat" ]]; then
        sed -i "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$tg_token|" "$INSTALL_DIR/.env"
        sed -i "s|TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=$tg_chat|" "$INSTALL_DIR/.env"

        NOTIFICATION_URLS="$NOTIFICATION_URLS tgram://$tg_token/$tg_chat"
        echo -e "${GREEN}Telegram configured!${NC}"
    fi
}

# Configure Gotify
configure_gotify() {
    echo ""
    echo -e "${BLUE}=== Gotify Configuration ===${NC}"
    echo "Gotify is a self-hosted push notification server."
    echo "After starting services, access it at: http://YOUR_IP:8070"
    echo ""

    read -p "Enter Gotify admin password [auto-generate]: " gotify_pass
    if [[ -z "$gotify_pass" ]]; then
        gotify_pass=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
        echo "Generated password: $gotify_pass"
    fi

    sed -i "s|GOTIFY_PASSWORD=.*|GOTIFY_PASSWORD=$gotify_pass|" "$INSTALL_DIR/.env"

    echo ""
    echo "Note: After Gotify starts, create an application to get an app token."
    echo "Use this token for Sonarr/Radarr notifications."

    # Create Gotify config for internal use
    NOTIFICATION_URLS="$NOTIFICATION_URLS gotify://gotify:80/GOTIFY_APP_TOKEN"
    echo -e "${GREEN}Gotify configured!${NC}"
}

# Configure ntfy
configure_ntfy() {
    echo ""
    echo -e "${BLUE}=== ntfy Configuration ===${NC}"
    echo "ntfy is a simple pub-sub notification service."
    echo "After starting, access it at: http://YOUR_IP:8071"
    echo ""

    echo "Setting up ntfy with default topic: mediahub"

    # ntfy will be accessible internally
    NOTIFICATION_URLS="$NOTIFICATION_URLS ntfy://ntfy:80/mediahub"
    echo -e "${GREEN}ntfy configured!${NC}"
    echo ""
    echo "Subscribe to notifications:"
    echo "  - Web: http://YOUR_IP:8071/mediahub"
    echo "  - Android/iOS: Download ntfy app, subscribe to your server"
}

# Configure Email (External SMTP)
configure_email() {
    echo ""
    echo -e "${BLUE}=== Email Configuration ===${NC}"
    echo "Configure an external SMTP server to send email notifications."
    echo ""

    read -p "SMTP Host (e.g., smtp.gmail.com): " smtp_host
    read -p "SMTP Port [587]: " smtp_port
    smtp_port=${smtp_port:-587}
    read -p "SMTP Username: " smtp_user
    read -sp "SMTP Password: " smtp_pass
    echo ""
    read -p "From Email: " smtp_from
    read -p "Notification Email (where to send): " notify_email

    if [[ -n "$smtp_host" && -n "$smtp_user" ]]; then
        sed -i "s|SMTP_HOST=.*|SMTP_HOST=$smtp_host|" "$INSTALL_DIR/.env"
        sed -i "s|SMTP_PORT=.*|SMTP_PORT=$smtp_port|" "$INSTALL_DIR/.env"
        sed -i "s|SMTP_USER=.*|SMTP_USER=$smtp_user|" "$INSTALL_DIR/.env"
        sed -i "s|SMTP_PASS=.*|SMTP_PASS=$smtp_pass|" "$INSTALL_DIR/.env"
        sed -i "s|SMTP_FROM=.*|SMTP_FROM=$smtp_from|" "$INSTALL_DIR/.env"
        sed -i "s|NOTIFICATION_EMAIL=.*|NOTIFICATION_EMAIL=$notify_email|" "$INSTALL_DIR/.env"

        NOTIFICATION_URLS="$NOTIFICATION_URLS mailto://$smtp_user:$smtp_pass@$smtp_host:$smtp_port?from=$smtp_from&to=$notify_email"
        echo -e "${GREEN}Email configured!${NC}"
    fi
}

# Process user choice
case $notify_method in
    1) configure_discord ;;
    2) configure_telegram ;;
    3) configure_gotify ;;
    4) configure_ntfy ;;
    5) configure_email ;;
    6)
        configure_discord
        configure_telegram
        configure_gotify
        configure_ntfy
        configure_email
        ;;
    *)
        echo -e "${YELLOW}Using default: Gotify${NC}"
        configure_gotify
        ;;
esac

# Create Mailrise configuration
echo ""
echo -e "${BLUE}Creating Mailrise SMTP configuration...${NC}"

cat > "$CONFIG_DIR/mailrise/mailrise.conf" << 'EOF'
# Mailrise - SMTP to Push Notification Gateway
# Automatically generated by setup-notifications.sh

configs:
  # Gotify (self-hosted push notifications)
  gotify:
    urls:
      - gotify://gotify:80/placeholder_token

  # ntfy (self-hosted push notifications)
  ntfy:
    urls:
      - ntfy://ntfy:80/mediahub

  # Catch-all (default destination)
  "*":
    urls:
      - gotify://gotify:80/placeholder_token

listen:
  host: 0.0.0.0
  port: 8025

smtp:
  hostname: mailrise
  auth_required: false
EOF

echo -e "${GREEN}Mailrise SMTP server configured!${NC}"

# Create Apprise configuration
echo ""
echo -e "${BLUE}Creating Apprise notification aggregator...${NC}"

cat > "$CONFIG_DIR/apprise/apprise.yml" << EOF
# Apprise - Universal Notification Configuration
# This file is used by Apprise API to send notifications

version: 1

# Define notification targets
urls:
$NOTIFICATION_URLS

# Group definitions for different alert types
groups:
  # Critical alerts (system down, disk full, VPN disconnected)
  critical:
    - gotify://gotify:80/placeholder_token?priority=high

  # Media alerts (new downloads, library updates)
  media:
    - gotify://gotify:80/placeholder_token?priority=normal

  # Info alerts (backups complete, updates available)
  info:
    - gotify://gotify:80/placeholder_token?priority=low
EOF

echo -e "${GREEN}Apprise API configured!${NC}"

# Create a notification test script
cat > "$INSTALL_DIR/scripts/test-notifications.sh" << 'EOF'
#!/bin/bash
# Test MediaHub notifications

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

echo "Testing MediaHub notifications..."
echo ""

# Test Gotify (if running)
if docker ps | grep -q gotify; then
    echo "Testing Gotify..."
    # This requires an app token - will be configured after first login
    echo "  Gotify is running. Configure app token in the web UI."
    echo "  Access: http://$(hostname -I | awk '{print $1}'):8070"
fi

# Test ntfy (if running)
if docker ps | grep -q ntfy; then
    echo "Testing ntfy..."
    curl -s -X POST http://localhost:8071/mediahub \
        -H "Title: MediaHub Test" \
        -d "This is a test notification from MediaHub"
    echo "  ntfy test sent to topic: mediahub"
fi

# Test Apprise API
if docker ps | grep -q apprise-api; then
    echo "Testing Apprise API..."
    curl -s -X POST http://localhost:8000/notify \
        -F "body=Test notification from MediaHub" \
        -F "title=MediaHub Test" > /dev/null 2>&1
    echo "  Apprise test sent"
fi

echo ""
echo "Check your notification channels for test messages."
echo "If nothing received, verify your configuration in .env file."
EOF

chmod +x "$INSTALL_DIR/scripts/test-notifications.sh"

# Create system notification helper
cat > "$INSTALL_DIR/scripts/notify.sh" << 'EOF'
#!/bin/bash
# Send notifications from MediaHub scripts
# Usage: ./notify.sh "Title" "Message" [priority]
# Priority: low, normal, high, urgent

TITLE="${1:-MediaHub Alert}"
MESSAGE="${2:-No message provided}"
PRIORITY="${3:-normal}"

# Send via ntfy (simplest option)
if docker ps | grep -q ntfy 2>/dev/null; then
    curl -s -X POST http://localhost:8071/mediahub \
        -H "Title: $TITLE" \
        -H "Priority: $PRIORITY" \
        -d "$MESSAGE" > /dev/null 2>&1
fi

# Send via Apprise API (if configured)
if docker ps | grep -q apprise-api 2>/dev/null; then
    curl -s -X POST http://localhost:8000/notify \
        -F "title=$TITLE" \
        -F "body=$MESSAGE" > /dev/null 2>&1
fi
EOF

chmod +x "$INSTALL_DIR/scripts/notify.sh"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Notification Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Services configured:"
echo "  - Mailrise (SMTP relay): port 8025"
echo "  - Gotify (push server): port 8070"
echo "  - Apprise API (universal notifier): port 8000"
echo "  - ntfy (pub-sub notifications): port 8071"
echo ""
echo "How to use notifications:"
echo ""
echo "1. For Sonarr/Radarr/Lidarr:"
echo "   Settings > Connect > Add > Gotify or Webhook"
echo "   Host: gotify (internal) or YOUR_IP:8070 (external)"
echo ""
echo "2. For qBittorrent:"
echo "   Options > Web UI > Run after completion:"
echo "   /opt/mediahub/scripts/notify.sh 'Download Complete' '%N'"
echo ""
echo "3. For custom scripts:"
echo "   /opt/mediahub/scripts/notify.sh 'Title' 'Message' [priority]"
echo ""
echo "4. Test notifications:"
echo "   $INSTALL_DIR/scripts/test-notifications.sh"
echo ""
echo "5. Subscribe to notifications:"
echo "   - Gotify: Download Gotify app (Android/F-Droid)"
echo "   - ntfy: Download ntfy app (iOS/Android)"
echo "   - Web: http://YOUR_IP:8071/mediahub"
echo ""

# Offer to start notification services
read -p "Start notification services now? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting notification services..."
    cd "$INSTALL_DIR"
    docker compose up -d mailrise gotify apprise-api ntfy

    sleep 5
    echo ""
    echo "Services started. Access:"
    local_ip=$(hostname -I | awk '{print $1}')
    echo "  - Gotify: http://$local_ip:8070"
    echo "  - ntfy: http://$local_ip:8071"
    echo "  - Apprise: http://$local_ip:8000"
fi
