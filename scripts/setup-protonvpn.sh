#!/bin/bash
# ProtonVPN Configuration Helper for MediaHub

echo "========================================="
echo "  ProtonVPN Setup for MediaHub"
echo "========================================="
echo ""

ENV_FILE="/opt/mediahub/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Please run the main installation first"
    exit 1
fi

echo "To get your ProtonVPN OpenVPN credentials:"
echo ""
echo "1. Go to: https://account.protonvpn.com/account#openvpn"
echo "2. Log in with your ProtonVPN account"
echo "3. Scroll down to 'OpenVPN / IKEv2 username'"
echo "4. Copy the username (NOT your email)"
echo "5. Copy the password"
echo ""
echo "IMPORTANT: These are NOT your ProtonVPN account credentials!"
echo "They are specific OpenVPN credentials that look like random strings."
echo ""

read -p "Enter your ProtonVPN OpenVPN username: " vpn_user
read -sp "Enter your ProtonVPN OpenVPN password: " vpn_pass
echo ""

# Update .env file
sed -i "s/PROTON_USER=.*/PROTON_USER=$vpn_user/" "$ENV_FILE"
sed -i "s/PROTON_PASS=.*/PROTON_PASS=$vpn_pass/" "$ENV_FILE"

echo ""
echo "ProtonVPN credentials saved!"
echo ""

# Country selection
echo "Available VPN server countries:"
echo "  - Netherlands (recommended for torrenting)"
echo "  - Switzerland"
echo "  - Sweden"
echo "  - Iceland"
echo ""

read -p "Enter preferred country (default: Netherlands): " vpn_country
vpn_country=${vpn_country:-Netherlands}

sed -i "s/VPN_COUNTRY=.*/VPN_COUNTRY=$vpn_country/" "$ENV_FILE"

echo "VPN country set to: $vpn_country"
echo ""

# Test VPN connection
read -p "Would you like to test the VPN connection? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Gluetun container to test VPN..."
    cd /opt/mediahub
    docker compose up -d gluetun
    sleep 10

    echo "Checking VPN status..."
    docker logs gluetun 2>&1 | tail -20

    echo ""
    echo "Testing external IP through VPN..."
    docker exec gluetun wget -qO- https://ipinfo.io
    echo ""

    read -p "Is the VPN working? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopping VPN container..."
        docker compose down gluetun
        echo ""
        echo "Please check your credentials and try again"
        echo "Common issues:"
        echo "  - Wrong credentials (must be OpenVPN credentials, not account)"
        echo "  - Country not available in your plan"
        echo "  - Network blocking VPN"
    else
        echo "VPN configured successfully!"
    fi
fi

echo ""
echo "Configuration complete!"
