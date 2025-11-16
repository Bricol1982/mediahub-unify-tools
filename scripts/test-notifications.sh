#!/bin/bash
# Test all notification channels

echo "Testing MediaHub Notification Channels..."
echo "========================================="

SCRIPT_DIR="$(dirname "$0")"

# Test each channel
echo ""
echo "1. Testing Gotify (self-hosted push)..."
"$SCRIPT_DIR/notify.sh" "Test Gotify" "This is a test from MediaHub" "normal"

echo ""
echo "2. Testing ntfy (pub-sub)..."
curl -s -X POST "http://localhost:8071/mediahub" \
    -H "Title: Test ntfy" \
    -d "MediaHub notification test" && echo " ✓ Sent"

echo ""
echo "3. Testing Apprise API..."
curl -s -X POST "http://localhost:8000/notify/" \
    -H "Content-Type: application/json" \
    -d '{"title": "Test Apprise", "body": "MediaHub test notification"}' && echo " ✓ Sent"

echo ""
echo "========================================="
echo "Check your notification apps/channels!"
echo ""
echo "Web interfaces:"
echo "  - Gotify: http://localhost:8070"
echo "  - ntfy: http://localhost:8071/mediahub"
echo "  - Apprise: http://localhost:8000"
