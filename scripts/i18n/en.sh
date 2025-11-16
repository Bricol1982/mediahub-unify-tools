#!/bin/bash
# English translations for MediaHub scripts

declare -gA TRANSLATIONS=(
    # Common
    ["common.yes"]="Yes"
    ["common.no"]="No"
    ["common.cancel"]="Cancel"
    ["common.confirm"]="Confirm"
    ["common.continue"]="Continue"
    ["common.back"]="Back"
    ["common.skip"]="Skip"
    ["common.error"]="Error"
    ["common.success"]="Success"
    ["common.warning"]="Warning"

    # Installer
    ["installer.title"]="MediaHub Installation"
    ["installer.welcome"]="Welcome to MediaHub Installation!"
    ["installer.welcome_desc"]="This wizard will configure your complete mediacenter.\n\nEstimated time: 15-30 minutes"

    ["installer.requirements"]="Before starting"
    ["installer.requirements_desc"]="Make sure you have:\n\n→ An external hard drive plugged in\n→ A VPN account (ProtonVPN, NordVPN, Mullvad, etc.)\n→ Your VPN OpenVPN/Wireguard credentials\n\nDo you have all these items?"

    ["installer.detecting_hardware"]="Detecting hardware..."
    ["installer.hardware_detected"]="Hardware detected"
    ["installer.rpi_model"]="Raspberry Pi Model"
    ["installer.ram_total"]="Total RAM"
    ["installer.hdd_detected"]="External hard drive"

    # VPN
    ["vpn.title"]="VPN Configuration"
    ["vpn.select_provider"]="Select your VPN provider"
    ["vpn.providers_info"]="MediaHub supports 24+ providers via Gluetun"
    ["vpn.username"]="Username"
    ["vpn.password"]="Password"
    ["vpn.credentials_warning"]="WARNING: These are your SERVICE credentials, not your account!"
    ["vpn.credentials_help"]="These credentials are different from your account email/password."
    ["vpn.server_country"]="Server country"
    ["vpn.server_region"]="Server region"
    ["vpn.username_short"]="Username seems too short."
    ["vpn.password_short"]="Password seems too short."
    ["vpn.test_connection"]="Testing VPN connection..."
    ["vpn.test_success"]="VPN connected successfully!"
    ["vpn.test_failed"]="VPN connection failed"

    # Master Password
    ["password.title"]="Master Password"
    ["password.desc"]="This password will protect all your credentials.\n\nIt will be used to encrypt your passwords.\n\nDO NOT FORGET IT!"
    ["password.enter"]="Enter your master password:"
    ["password.confirm"]="Confirm your master password:"
    ["password.mismatch"]="Passwords do not match!"
    ["password.weak"]="Password must be at least 8 characters."
    ["password.strength"]="Password strength"
    ["password.weak_label"]="Weak"
    ["password.medium_label"]="Medium"
    ["password.strong_label"]="Strong"

    # Features
    ["features.title"]="Optional features"
    ["features.desc"]="Select features to enable:"
    ["features.tv_kiosk"]="TV Kiosk Mode (fullscreen display)"
    ["features.hdmi_cec"]="HDMI-CEC Control (TV remote)"
    ["features.notifications"]="Notifications (Discord, Telegram, etc.)"
    ["features.monitoring"]="System monitoring (temperature, CPU)"

    # Installation
    ["install.starting"]="Starting installation..."
    ["install.creating_dirs"]="Creating directories..."
    ["install.pulling_images"]="Downloading Docker images..."
    ["install.configuring"]="Configuring services..."
    ["install.starting_services"]="Starting services..."
    ["install.complete"]="Installation complete!"
    ["install.error"]="Error during installation"
    ["install.rollback"]="Error detected, rolling back..."

    # Notifications
    ["notify.title"]="Notification configuration"
    ["notify.discord"]="Discord"
    ["notify.telegram"]="Telegram"
    ["notify.gotify"]="Gotify (self-hosted)"
    ["notify.email"]="Email"
    ["notify.webhook_url"]="Webhook URL"
    ["notify.bot_token"]="Bot token"
    ["notify.chat_id"]="Chat ID"

    # Services
    ["services.jellyfin"]="Jellyfin - Media player"
    ["services.sonarr"]="Sonarr - TV Series"
    ["services.radarr"]="Radarr - Movies"
    ["services.prowlarr"]="Prowlarr - Indexers"
    ["services.qbittorrent"]="qBittorrent - Downloads"

    # Post-install
    ["postinstall.title"]="Post-installation configuration"
    ["postinstall.api_keys"]="Retrieving API keys..."
    ["postinstall.linking"]="Linking services..."
    ["postinstall.complete"]="Automatic configuration complete!"

    # Summary
    ["summary.title"]="Installation summary"
    ["summary.provider"]="VPN Provider"
    ["summary.features"]="Enabled features"
    ["summary.passwords"]="Generated passwords"
    ["summary.ready"]="Everything is ready!"
    ["summary.access"]="Access your dashboard"
    ["summary.credentials"]="View credentials"

    # Hardware Mode
    ["hardware.title"]="Installation Mode"
    ["hardware.description"]="Select your hardware to optimize installation"
    ["hardware.pi4_full"]="Raspberry Pi 4 - All services"
    ["hardware.pi3_limited"]="Raspberry Pi 3 - Limited mode"
    ["hardware.detected"]="Hardware detected"
    ["hardware.ram"]="RAM"
    ["hardware.mode_full"]="Full mode"
    ["hardware.mode_limited"]="Limited mode"
    ["hardware.services_included"]="Services included"
    ["hardware.services_excluded"]="Services excluded"
)
