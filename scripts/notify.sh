#!/bin/bash
# MediaHub Notification Helper
# Usage: ./notify.sh "Title" "Message" [priority]

TITLE="${1:-MediaHub}"
MESSAGE="${2:-Test notification}"
PRIORITY="${3:-normal}"

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

# Load configuration if exists
if [[ -f "$INSTALL_DIR/.env" ]]; then
    source "$INSTALL_DIR/.env"
fi

# Try Gotify first (self-hosted)
if [[ -n "$GOTIFY_TOKEN" ]]; then
    priority_num=5
    [[ "$PRIORITY" == "high" ]] && priority_num=8
    [[ "$PRIORITY" == "urgent" ]] && priority_num=10

    curl -s -X POST "http://localhost:8070/message" \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -F "title=$TITLE" \
        -F "message=$MESSAGE" \
        -F "priority=$priority_num" >/dev/null 2>&1 && echo "✓ Gotify"
fi

# Try ntfy (pub-sub)
curl -s -X POST "http://localhost:8071/mediahub" \
    -H "Title: $TITLE" \
    -H "Priority: ${PRIORITY:-default}" \
    -d "$MESSAGE" >/dev/null 2>&1 && echo "✓ ntfy"

# Try Apprise API
if [[ -n "$APPRISE_CONFIG" ]]; then
    curl -s -X POST "http://localhost:8000/notify/" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$TITLE\", \"body\": \"$MESSAGE\"}" >/dev/null 2>&1 && echo "✓ Apprise"
fi

# Log to file
LOG_FILE="$INSTALL_DIR/logs/notifications.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S')|$PRIORITY|$TITLE|$MESSAGE" >> "$LOG_FILE"

exit 0
