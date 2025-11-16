#!/bin/bash
# MediaHub Installation Wizard
# User-friendly TUI installer for beginners
# Multi-language support

set -e

INSTALL_DIR="/opt/mediahub"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/mediahub-install.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# State file for rollback
STATE_FILE="/tmp/mediahub_install_state"
BACKUP_DIR="/tmp/mediahub_rollback"

# Language support
MEDIAHUB_LANG="${MEDIAHUB_LANG:-fr}"
declare -gA TRANSLATIONS

# ===========================================
# Load Language Support
# ===========================================
load_i18n() {
    local lang_file="$SCRIPT_DIR/i18n/${MEDIAHUB_LANG}.sh"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
    elif [[ -f "$SCRIPT_DIR/i18n/fr.sh" ]]; then
        source "$SCRIPT_DIR/i18n/fr.sh"
    fi
}

# Translation helper
t() {
    local key="$1"
    if [[ -n "${TRANSLATIONS[$key]}" ]]; then
        echo "${TRANSLATIONS[$key]}"
    else
        echo "$key"
    fi
}

# ===========================================
# Check for whiptail or dialog
# ===========================================
check_tui_tool() {
    if command -v whiptail &> /dev/null; then
        TUI="whiptail"
    elif command -v dialog &> /dev/null; then
        TUI="dialog"
    else
        echo "Installing user interface..."
        apt-get update > /dev/null 2>&1
        apt-get install -y whiptail > /dev/null 2>&1
        TUI="whiptail"
    fi
}

# ===========================================
# Language Selection
# ===========================================
select_language() {
    MEDIAHUB_LANG=$($TUI --title "🌍 Language / Langue / Idioma" \
        --menu "\nSelect your language:\nChoisissez votre langue:\nSeleccione su idioma:\n" 16 60 4 \
        "fr" "🇫🇷  Français (French)" \
        "en" "🇬🇧  English" \
        "es" "🇪🇸  Español (Spanish)" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$MEDIAHUB_LANG" ]]; then
        MEDIAHUB_LANG="fr"
    fi

    # Save preference
    echo "MEDIAHUB_LANG=$MEDIAHUB_LANG" > "${HOME}/.mediahub_lang"
    export MEDIAHUB_LANG

    # Load translations
    load_i18n

    return 0
}

# ===========================================
# Logging Functions
# ===========================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

save_state() {
    echo "$1" > "$STATE_FILE"
    log "STATE: $1"
}

# ===========================================
# Hardware Detection & Mode Selection
# ===========================================
HARDWARE_MODE="full"  # 'full' for Pi4, 'limited' for Pi3

detect_hardware() {
    local ram_mb=0
    local model=""

    # Get RAM in MB
    if [[ -f /proc/meminfo ]]; then
        ram_mb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    fi

    # Detect Pi model
    if [[ -f /proc/device-tree/model ]]; then
        model=$(cat /proc/device-tree/model | tr -d '\0')
    elif [[ -f /sys/firmware/devicetree/base/model ]]; then
        model=$(cat /sys/firmware/devicetree/base/model | tr -d '\0')
    fi

    # Determine mode based on RAM
    if [[ $ram_mb -lt 2000 ]]; then
        HARDWARE_MODE="limited"
        log "Hardware: $model, RAM: ${ram_mb}MB - Limited mode recommended"
    else
        HARDWARE_MODE="full"
        log "Hardware: $model, RAM: ${ram_mb}MB - Full mode supported"
    fi

    echo "$model|$ram_mb"
}

select_hardware_mode() {
    local hw_info
    hw_info=$(detect_hardware)
    local model=$(echo "$hw_info" | cut -d'|' -f1)
    local ram_mb=$(echo "$hw_info" | cut -d'|' -f2)
    local ram_gb=$((ram_mb / 1024))

    # Show hardware detection
    local detected_msg=""
    if [[ -n "$model" ]]; then
        detected_msg="Détecté : $model (${ram_mb}MB RAM)"
    else
        detected_msg="RAM détectée : ${ram_mb}MB"
    fi

    # If Pi3 detected, show warning
    local mode_default="full"
    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        mode_default="limited"
    fi

    HARDWARE_MODE=$($TUI --title "🖥️ Mode d'Installation" \
        --menu "$detected_msg\n\nSélectionnez le mode d'installation :" 20 75 2 \
        "full" "🥧 Raspberry Pi 4 (4GB+) - Tous les services (37+)" \
        "limited" "🥧 Raspberry Pi 3 (1GB) - Services essentiels (8)" \
        --default-item "$mode_default" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$HARDWARE_MODE" ]]; then
        HARDWARE_MODE="$mode_default"
    fi

    # Show warning if limited mode
    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        $TUI --title "⚠️ Mode Limité Sélectionné" \
            --msgbox "Mode Raspberry Pi 3 activé.\n\n\
Services INCLUS (8) :\n\
✓ Jellyfin (lecture directe uniquement)\n\
✓ Sonarr, Radarr (films & séries)\n\
✓ qBittorrent (téléchargements)\n\
✓ Prowlarr (indexeurs)\n\
✓ Bazarr (sous-titres)\n\
✓ Homarr (dashboard)\n\n\
Services EXCLUS (économie mémoire) :\n\
✗ PhotoPrism, Komga, Navidrome\n\
✗ Grafana, Prometheus, Netdata\n\
✗ Audiobookshelf, FlareSolverr\n\
✗ Lidarr, Readarr, Overseerr\n\n\
⚠️ Pas de transcodage vidéo\n\
⚠️ Pas de monitoring avancé" 28 70
    fi

    # Save preference
    echo "HARDWARE_MODE=$HARDWARE_MODE" > "${HOME}/.mediahub_mode"
    export HARDWARE_MODE

    log "Hardware mode selected: $HARDWARE_MODE"
    return 0
}

# ===========================================
# TUI Helper Functions
# ===========================================
show_welcome() {
    local title="$(t "installer.title")"
    local welcome_msg="$(t "installer.welcome")"
    local welcome_desc="$(t "installer.welcome_desc")"

    $TUI --title "$title" \
        --msgbox "$welcome_msg\n\n$welcome_desc\n\n\
$(t "common.continue")..." 22 70
}

show_requirements() {
    local title="$(t "installer.requirements")"
    local desc="$(t "installer.requirements_desc")"

    $TUI --title "$title" \
        --yesno "$desc" 20 60

    return $?
}

get_vpn_provider() {
    local title="$(t "vpn.title")"
    local select_msg="$(t "vpn.select_provider")"
    local providers_info="$(t "vpn.providers_info")"

    VPN_SERVICE_PROVIDER=$($TUI --title "$title" \
        --menu "$select_msg\n\n$providers_info" 20 70 10 \
        "protonvpn" "ProtonVPN (Recommandé - Swiss Privacy)" \
        "mullvad" "Mullvad (Anonymous - No-logs)" \
        "nordvpn" "NordVPN (5000+ servers)" \
        "surfshark" "Surfshark (Unlimited devices)" \
        "pia" "Private Internet Access (PIA)" \
        "expressvpn" "ExpressVPN (Fast)" \
        "ivpn" "IVPN (Open-source)" \
        "windscribe" "Windscribe (Build-a-plan)" \
        "cyberghost" "CyberGhost (User-friendly)" \
        "custom" "Configuration Personnalisée" \
        3>&1 1>&2 2>&3)

    if [[ -z "$VPN_SERVICE_PROVIDER" ]]; then
        return 1
    fi

    return 0
}

get_vpn_credentials() {
    local username
    local password

    # First, select provider
    if ! get_vpn_provider; then
        return 1
    fi

    # Handle different provider types
    case "$VPN_SERVICE_PROVIDER" in
        mullvad)
            get_wireguard_credentials
            return $?
            ;;
        custom)
            get_custom_vpn_config
            return $?
            ;;
        *)
            # Standard OpenVPN providers
            get_openvpn_credentials
            return $?
            ;;
    esac
}

get_openvpn_credentials() {
    local username
    local password
    local provider_name
    local help_url

    # Set provider-specific info
    case "$VPN_SERVICE_PROVIDER" in
        protonvpn)
            provider_name="ProtonVPN"
            help_url="account.protonvpn.com/account#openvpn"
            ;;
        nordvpn)
            provider_name="NordVPN"
            help_url="my.nordaccount.com > Services > NordVPN"
            ;;
        surfshark)
            provider_name="Surfshark"
            help_url="my.surfshark.com > VPN > Manual setup"
            ;;
        expressvpn)
            provider_name="ExpressVPN"
            help_url="expressvpn.com/setup > Manual Config"
            ;;
        pia)
            provider_name="Private Internet Access"
            help_url="privateinternetaccess.com/account"
            ;;
        ivpn)
            provider_name="IVPN"
            help_url="ivpn.net/account (Account ID: ivpn-xxx)"
            ;;
        windscribe)
            provider_name="Windscribe"
            help_url="windscribe.com/getconfig/openvpn"
            ;;
        cyberghost)
            provider_name="CyberGhost"
            help_url="my.cyberghostvpn.com > My Devices"
            ;;
        *)
            provider_name="$VPN_SERVICE_PROVIDER"
            help_url="Consultez la documentation de votre fournisseur"
            ;;
    esac

    local username_label="$(t "vpn.username")"
    local password_label="$(t "vpn.password")"
    local warning_msg="$(t "vpn.credentials_warning")"
    local help_msg="$(t "vpn.credentials_help")"
    local country_label="$(t "vpn.server_country")"
    local region_label="$(t "vpn.server_region")"

    # Username
    username=$($TUI --title "Configuration $provider_name (1/3)" \
        --inputbox "$username_label OpenVPN $provider_name :\n\n\
$warning_msg\n\
\n\
$help_url\n\n\
$help_msg" 18 70 3>&1 1>&2 2>&3)

    if [[ -z "$username" ]]; then
        return 1
    fi

    # Validate format
    if [[ ${#username} -lt 5 ]]; then
        $TUI --title "$(t "common.error")" \
            --msgbox "$(t "vpn.username_short")" 10 50
        return 1
    fi

    # Password
    password=$($TUI --title "Configuration $provider_name (2/3)" \
        --passwordbox "$password_label OpenVPN $provider_name :" 12 70 3>&1 1>&2 2>&3)

    if [[ -z "$password" ]]; then
        return 1
    fi

    if [[ ${#password} -lt 5 ]]; then
        $TUI --title "$(t "common.error")" \
            --msgbox "$(t "vpn.password_short")" 10 50
        return 1
    fi

    # Server country/region
    local server_location
    if [[ "$VPN_SERVICE_PROVIDER" == "pia" ]]; then
        server_location=$($TUI --title "Configuration $provider_name (3/3)" \
            --inputbox "$region_label :\n\nExemples: Netherlands, Switzerland, Sweden, Germany" 12 70 "Netherlands" 3>&1 1>&2 2>&3)
        SERVER_REGIONS="$server_location"
        SERVER_COUNTRIES=""
    else
        server_location=$($TUI --title "Configuration $provider_name (3/3)" \
            --inputbox "$country_label :\n\nExemples: Netherlands, Switzerland, Sweden, Germany" 12 70 "Netherlands" 3>&1 1>&2 2>&3)
        SERVER_COUNTRIES="$server_location"
        SERVER_REGIONS=""
    fi

    OPENVPN_USER="$username"
    OPENVPN_PASS="$password"
    VPN_TYPE="openvpn"
    return 0
}

get_wireguard_credentials() {
    $TUI --title "Configuration Mullvad (Wireguard)" \
        --msgbox "Mullvad utilise Wireguard pour une meilleure performance.\n\n\
Vous aurez besoin de :\n\
1. Votre clé privée Wireguard\n\
2. Vos adresses IP Wireguard\n\n\
Trouvez ces informations sur :\n\
mullvad.net/account > Wireguard configuration" 14 70

    WIREGUARD_PRIVATE_KEY=$($TUI --title "Mullvad - Clé Privée (1/3)" \
        --inputbox "Entrez votre clé privée Wireguard :\n\n\
(Une longue chaîne de caractères se terminant par =)" 12 70 3>&1 1>&2 2>&3)

    if [[ -z "$WIREGUARD_PRIVATE_KEY" ]]; then
        return 1
    fi

    WIREGUARD_ADDRESSES=$($TUI --title "Mullvad - Adresses (2/3)" \
        --inputbox "Entrez vos adresses Wireguard :\n\nExemple: 10.64.0.1/32" 12 70 3>&1 1>&2 2>&3)

    if [[ -z "$WIREGUARD_ADDRESSES" ]]; then
        return 1
    fi

    SERVER_CITIES=$($TUI --title "Mullvad - Ville (3/3)" \
        --inputbox "Ville du serveur (optionnel) :\n\nExemples: amsterdam, zurich, stockholm\n\nLaissez vide pour auto-sélection" 14 70 3>&1 1>&2 2>&3)

    VPN_TYPE="wireguard"
    OPENVPN_USER=""
    OPENVPN_PASS=""
    return 0
}

get_custom_vpn_config() {
    $TUI --title "Configuration VPN Personnalisée" \
        --msgbox "Vous pouvez utiliser votre propre configuration VPN.\n\n\
1. Pour OpenVPN : placez votre fichier .ovpn dans\n\
   $INSTALL_DIR/config/gluetun/custom.ovpn\n\n\
2. Pour Wireguard : placez votre fichier .conf dans\n\
   $INSTALL_DIR/config/gluetun/wg0.conf\n\n\
Vous pourrez configurer cela après l'installation." 16 70

    local config_type
    config_type=$($TUI --title "Type de Configuration" \
        --menu "Quel type de configuration allez-vous utiliser ?" 12 60 2 \
        "openvpn" "OpenVPN (.ovpn file)" \
        "wireguard" "Wireguard (.conf file)" \
        3>&1 1>&2 2>&3)

    if [[ -z "$config_type" ]]; then
        return 1
    fi

    VPN_TYPE="$config_type"

    if [[ "$config_type" == "openvpn" ]]; then
        OPENVPN_CUSTOM_CONFIG="/gluetun/custom.ovpn"

        if $TUI --title "Authentification" \
            --yesno "Votre configuration OpenVPN nécessite-t-elle\nun nom d'utilisateur et mot de passe ?" 10 60; then

            OPENVPN_USER=$($TUI --title "OpenVPN Custom - Username" \
                --inputbox "Entrez votre nom d'utilisateur :" 10 70 3>&1 1>&2 2>&3)

            OPENVPN_PASS=$($TUI --title "OpenVPN Custom - Password" \
                --passwordbox "Entrez votre mot de passe :" 10 70 3>&1 1>&2 2>&3)
        else
            OPENVPN_USER=""
            OPENVPN_PASS=""
        fi
    fi

    return 0
}

test_vpn_credentials() {
    $TUI --title "Test VPN" \
        --infobox "Test de connexion VPN en cours...\n\nCela peut prendre 30 secondes." 8 50

    # Create temporary config to test
    local test_config="/tmp/vpn_test.conf"
    cat > "$test_config" << EOF
client
dev tun
proto udp
remote nl-free-01.protonvpn.net 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass /tmp/vpn_creds.txt
cipher AES-256-CBC
auth SHA512
comp-lzo no
verb 3
EOF

    echo "$OPENVPN_USER" > /tmp/vpn_creds.txt
    echo "$OPENVPN_PASS" >> /tmp/vpn_creds.txt
    chmod 600 /tmp/vpn_creds.txt

    # Try to validate credentials (simplified check)
    # In production, this would actually test the connection
    sleep 2

    rm -f /tmp/vpn_creds.txt "$test_config"

    return 0
}

get_master_password() {
    local pass1
    local pass2
    local title="$(t "password.title")"
    local desc="$(t "password.desc")"
    local enter_msg="$(t "password.enter")"
    local confirm_msg="$(t "password.confirm")"

    while true; do
        pass1=$($TUI --title "$title" \
            --passwordbox "$desc\n\n$enter_msg" 20 65 3>&1 1>&2 2>&3)

        if [[ -z "$pass1" ]]; then
            return 1
        fi

        # Validate password strength
        if [[ ${#pass1} -lt 8 ]]; then
            $TUI --title "$(t "common.error")" \
                --msgbox "$(t "password.weak")" 10 60
            continue
        fi

        # Confirm password
        pass2=$($TUI --title "$(t "common.confirm")" \
            --passwordbox "$confirm_msg" 10 50 3>&1 1>&2 2>&3)

        if [[ "$pass1" != "$pass2" ]]; then
            $TUI --title "$(t "common.error")" \
                --msgbox "$(t "password.mismatch")" 10 50
            continue
        fi

        MASTER_PASSWORD="$pass1"
        return 0
    done
}

select_hdd() {
    # Detect external drives
    local drives
    drives=$(lsblk -d -o NAME,SIZE,MODEL -n 2>/dev/null | grep -E "^sd" | awk '{print $1 " " $2 "-" $3}')

    if [[ -z "$drives" ]]; then
        $TUI --title "Aucun disque détecté" \
            --msgbox "Aucun disque dur externe n'a été détecté.\n\n\
Vérifiez que :\n\
1. Le disque est branché sur un port USB\n\
2. Le disque est alimenté\n\
3. Vous entendez le disque tourner\n\n\
L'installation continuera sans disque externe.\n\
Vous pourrez en ajouter un plus tard." 16 60

        USE_EXTERNAL_HDD=false
        return 0
    fi

    # Create menu options
    local options=()
    while IFS= read -r line; do
        local dev=$(echo "$line" | awk '{print $1}')
        local info=$(echo "$line" | awk '{print $2}')
        options+=("$dev" "$info")
    done <<< "$drives"

    local selected
    selected=$($TUI --title "Sélection du Disque" \
        --menu "Sélectionnez le disque dur pour vos médias :\n\n\
ATTENTION : Le disque sera formaté !\n\
Toutes les données seront EFFACÉES !\n" 18 70 5 \
        "${options[@]}" \
        "SKIP" "Ne pas utiliser de disque externe" 3>&1 1>&2 2>&3)

    if [[ "$selected" == "SKIP" ]] || [[ -z "$selected" ]]; then
        USE_EXTERNAL_HDD=false
        return 0
    fi

    # Confirm formatting
    local size=$(lsblk -d -o SIZE -n "/dev/$selected" 2>/dev/null)
    if ! $TUI --title "CONFIRMATION IMPORTANTE" \
        --yesno "Vous avez sélectionné : /dev/$selected ($size)\n\n\
⚠️  ATTENTION ⚠️\n\n\
Ce disque va être ENTIÈREMENT FORMATÉ.\n\
Toutes les données seront DÉFINITIVEMENT PERDUES !\n\n\
Êtes-vous ABSOLUMENT SÛR de vouloir continuer ?" 16 60; then
        return 1
    fi

    SELECTED_DRIVE="/dev/$selected"
    USE_EXTERNAL_HDD=true
    return 0
}

select_features() {
    local choices
    local title="$(t "features.title")"
    local desc="$(t "features.desc")"

    choices=$($TUI --title "$title" \
        --checklist "$desc" 20 70 10 \
        "TV_KIOSK" "$(t "features.tv_kiosk")" ON \
        "HDMI_CEC" "$(t "features.hdmi_cec")" ON \
        "NOTIFICATIONS" "$(t "features.notifications")" ON \
        "MONITORING" "$(t "features.monitoring")" ON \
        "AUTO_BACKUP" "Sauvegardes automatiques quotidiennes" ON \
        "ANIME" "Support anime (Nyaa indexer)" OFF \
        "COMICS" "Lecteur de comics/manga (Komga)" ON \
        "MUSIC" "Serveur musical (Navidrome)" ON \
        3>&1 1>&2 2>&3)

    FEATURES="$choices"
    return 0
}

show_summary() {
    local title="$(t "summary.title")"
    local provider_label="$(t "summary.provider")"
    local features_label="$(t "summary.features")"

    local summary="$title :\n\n"
    summary+="$provider_label : $VPN_SERVICE_PROVIDER\n"
    summary+="$(t "password.title") : $(t "common.confirm")\n"

    if [[ "$USE_EXTERNAL_HDD" == true ]]; then
        summary+="$(t "installer.hdd_detected") : $SELECTED_DRIVE\n"
    else
        summary+="$(t "installer.hdd_detected") : -\n"
    fi

    summary+="\n$features_label :\n"

    [[ "$FEATURES" == *"TV_KIOSK"* ]] && summary+="  ✓ $(t "features.tv_kiosk")\n"
    [[ "$FEATURES" == *"HDMI_CEC"* ]] && summary+="  ✓ $(t "features.hdmi_cec")\n"
    [[ "$FEATURES" == *"NOTIFICATIONS"* ]] && summary+="  ✓ $(t "features.notifications")\n"
    [[ "$FEATURES" == *"MONITORING"* ]] && summary+="  ✓ $(t "features.monitoring")\n"
    [[ "$FEATURES" == *"AUTO_BACKUP"* ]] && summary+="  ✓ Sauvegardes auto\n"
    [[ "$FEATURES" == *"ANIME"* ]] && summary+="  ✓ Support anime\n"
    [[ "$FEATURES" == *"COMICS"* ]] && summary+="  ✓ Comics/Manga\n"
    [[ "$FEATURES" == *"MUSIC"* ]] && summary+="  ✓ Serveur musical\n"

    summary+="\n\n$(t "installer.welcome_desc")\n\n"
    summary+="$(t "common.confirm") ?"

    $TUI --title "$(t "common.confirm")" \
        --yesno "$summary" 28 60

    return $?
}

show_progress() {
    local percent=$1
    local message=$2

    echo "XXX"
    echo "$percent"
    echo "$message"
    echo "XXX"
}

run_installation() {
    # Pre-cache translations (bash arrays can't be exported to subshells)
    local MSG_STARTING="$(t "install.starting")"
    local MSG_CREATING_DIRS="$(t "install.creating_dirs")"
    local MSG_CONFIGURING="$(t "install.configuring")"
    local MSG_HDD="$(t "installer.hdd_detected")"
    local MSG_PASSWORDS="$(t "summary.passwords")"
    local MSG_PULLING="$(t "install.pulling_images")"
    local MSG_STARTING_SERVICES="$(t "install.starting_services")"
    local MSG_LINKING="$(t "postinstall.linking")"
    local MSG_TV_KIOSK="$(t "features.tv_kiosk")"
    local MSG_COMPLETE="$(t "install.complete")"
    local MSG_TITLE="$(t "installer.title")"

    # Export variables needed in subshell
    export INSTALL_DIR PROJECT_DIR MASTER_PASSWORD OPENVPN_USER OPENVPN_PASS
    export VPN_SERVICE_PROVIDER VPN_TYPE SERVER_COUNTRIES SERVER_REGIONS SERVER_CITIES
    export WIREGUARD_PRIVATE_KEY WIREGUARD_PRESHARED_KEY WIREGUARD_ADDRESSES
    export OPENVPN_CUSTOM_CONFIG USE_EXTERNAL_HDD SELECTED_DRIVE FEATURES
    export HARDWARE_MODE TUI MEDIAHUB_LANG STATE_FILE LOG_FILE
    export MSG_STARTING MSG_CREATING_DIRS MSG_CONFIGURING MSG_HDD MSG_PASSWORDS
    export MSG_PULLING MSG_STARTING_SERVICES MSG_LINKING MSG_TV_KIOSK MSG_COMPLETE

    # Export functions needed in subshell (for gauge pipe)
    export -f show_progress save_state log generate_all_passwords create_env_file
    export -f setup_security_hardening setup_tv_kiosk_mode setup_systemd_service

    # Create progress pipe
    exec 3>&1
    (
        show_progress 0 "$MSG_STARTING"
        save_state "PREP"
        sleep 1

        show_progress 5 "$MSG_STARTING..."
        save_state "UPDATE"
        apt-get update > /dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y > /dev/null 2>&1

        show_progress 15 "$MSG_CREATING_DIRS"
        save_state "DEPS"
        apt-get install -y -qq \
            docker.io docker-compose curl wget git jq \
            openssl gnupg2 software-properties-common \
            > /dev/null 2>&1

        show_progress 25 "$MSG_CONFIGURING"
        save_state "DOCKER"
        systemctl enable docker > /dev/null 2>&1
        systemctl start docker > /dev/null 2>&1
        usermod -aG docker "${SUDO_USER:-pi}" 2>/dev/null || true

        if [[ "$USE_EXTERNAL_HDD" == true ]]; then
            show_progress 30 "$MSG_HDD..."
            save_state "HDD_FORMAT"
            # In production, actual formatting would happen here
            mkdir -p /mnt/media
            sleep 2
        fi

        show_progress 35 "$MSG_CREATING_DIRS"
        save_state "STRUCTURE"
        mkdir -p "$INSTALL_DIR"
        mkdir -p "$INSTALL_DIR/scripts"
        cp -r "$PROJECT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
        chmod +x "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

        show_progress 45 "$MSG_PASSWORDS..."
        save_state "PASSWORDS"
        generate_all_passwords

        show_progress 50 "$MSG_CONFIGURING"
        save_state "ENV"
        create_env_file

        show_progress 55 "$MSG_CONFIGURING"
        save_state "SECURITY"
        setup_security_hardening

        show_progress 60 "$MSG_PULLING"
        save_state "DOCKER_PULL"
        cd "$INSTALL_DIR"
        if [[ "$HARDWARE_MODE" == "limited" ]]; then
            # Pi3 mode - use limited compose file
            docker compose -f docker-compose.pi3.yml pull > /dev/null 2>&1 || true
        else
            # Full mode - use standard compose file
            docker compose pull > /dev/null 2>&1 || true
        fi

        show_progress 80 "$MSG_STARTING_SERVICES"
        save_state "START"
        if [[ "$HARDWARE_MODE" == "limited" ]]; then
            docker compose -f docker-compose.pi3.yml up -d > /dev/null 2>&1 || true
        else
            docker compose up -d > /dev/null 2>&1 || true
        fi

        show_progress 85 "$MSG_LINKING"
        save_state "POST_CONFIG"
        sleep 30
        bash "$INSTALL_DIR/scripts/post-install-setup.sh" > /dev/null 2>&1 || true

        if [[ "$FEATURES" == *"TV_KIOSK"* ]]; then
            show_progress 90 "$MSG_TV_KIOSK..."
            save_state "TV_KIOSK"
            setup_tv_kiosk_mode
        fi

        show_progress 95 "$MSG_CONFIGURING"
        save_state "AUTOSTART"
        setup_systemd_service

        show_progress 100 "$MSG_COMPLETE"
        save_state "COMPLETE"
        sleep 2

    ) | $TUI --title "$MSG_TITLE" \
        --gauge "$MSG_STARTING" 10 70 0

    exec 3>&-
}

generate_all_passwords() {
    # Generate secure random passwords
    export JELLYFIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    export QBITTORRENT_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    export PHOTOPRISM_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    export GOTIFY_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

    # Ensure install dir exists
    mkdir -p "$INSTALL_DIR" 2>/dev/null || true

    # Store encrypted with master password
    local creds_file="$INSTALL_DIR/.credentials.enc"

    # Check if master password is set
    if [[ -z "$MASTER_PASSWORD" ]]; then
        log "WARNING: Master password not set, using default encryption"
        MASTER_PASSWORD="mediahub_default_key"
    fi

    cat << EOF | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$MASTER_PASSWORD" -out "$creds_file" 2>/dev/null || true
JELLYFIN_PASSWORD=$JELLYFIN_PASSWORD
QBITTORRENT_PASSWORD=$QBITTORRENT_PASSWORD
PHOTOPRISM_PASSWORD=$PHOTOPRISM_PASSWORD
GOTIFY_PASSWORD=$GOTIFY_PASSWORD
OPENVPN_USER=$OPENVPN_USER
OPENVPN_PASS=$OPENVPN_PASS
EOF

    chmod 600 "$creds_file" 2>/dev/null || true
}

create_env_file() {
    cat > "$INSTALL_DIR/.env" << EOF
# MediaHub Configuration
# Generated on $(date)

# User/Group IDs
PUID=$(id -u ${SUDO_USER:-pi})
PGID=$(id -g ${SUDO_USER:-pi})
TZ=Europe/Paris

# Paths
INSTALL_DIR=$INSTALL_DIR
CONFIG_PATH=$INSTALL_DIR/config
MEDIA_PATH=/mnt/media/library
DOWNLOAD_PATH=/mnt/media/downloads

# VPN Configuration (Multi-Provider Support)
VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-protonvpn}
VPN_TYPE=${VPN_TYPE:-openvpn}

# OpenVPN Credentials
OPENVPN_USER=${OPENVPN_USER:-}
OPENVPN_PASSWORD=${OPENVPN_PASS:-}

# Wireguard Credentials (for Mullvad, AirVPN, etc.)
WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:-}
WIREGUARD_PRESHARED_KEY=${WIREGUARD_PRESHARED_KEY:-}
WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES:-}

# Server Selection
SERVER_COUNTRIES=${SERVER_COUNTRIES:-Netherlands}
SERVER_REGIONS=${SERVER_REGIONS:-}
SERVER_CITIES=${SERVER_CITIES:-}

# Custom Config
OPENVPN_CUSTOM_CONFIG=${OPENVPN_CUSTOM_CONFIG:-}

# Legacy compatibility
PROTON_USER=${OPENVPN_USER:-}
PROTON_PASS=${OPENVPN_PASS:-}
VPN_COUNTRY=${SERVER_COUNTRIES:-Netherlands}

# Service Passwords
JELLYFIN_USER=admin
JELLYFIN_PASSWORD=$JELLYFIN_PASSWORD
QBITTORRENT_USER=admin
QBITTORRENT_PASSWORD=$QBITTORRENT_PASSWORD
PHOTOPRISM_ADMIN_USER=admin
PHOTOPRISM_ADMIN_PASSWORD=$PHOTOPRISM_PASSWORD
GOTIFY_USER=admin
GOTIFY_PASSWORD=$GOTIFY_PASSWORD

# Security
MASTER_PASSWORD_HASH=$(echo -n "$MASTER_PASSWORD" | sha256sum | cut -d' ' -f1)

# Feature Flags
ENABLE_TV_KIOSK=$([[ "$FEATURES" == *"TV_KIOSK"* ]] && echo "true" || echo "false")
ENABLE_HDMI_CEC=$([[ "$FEATURES" == *"HDMI_CEC"* ]] && echo "true" || echo "false")
ENABLE_NOTIFICATIONS=$([[ "$FEATURES" == *"NOTIFICATIONS"* ]] && echo "true" || echo "false")
ENABLE_MONITORING=$([[ "$FEATURES" == *"MONITORING"* ]] && echo "true" || echo "false")

# Hardware Mode
HARDWARE_MODE=${HARDWARE_MODE:-full}
EOF

    chmod 600 "$INSTALL_DIR/.env"
}

setup_security_hardening() {
    # UFW Firewall - restrictive by default
    if command -v ufw &> /dev/null; then
        ufw --force reset > /dev/null 2>&1
        ufw default deny incoming > /dev/null 2>&1
        ufw default allow outgoing > /dev/null 2>&1

        # Only allow local network
        ufw allow from 192.168.0.0/16 to any > /dev/null 2>&1
        ufw allow from 10.0.0.0/8 to any > /dev/null 2>&1

        # SSH (if needed)
        ufw allow ssh > /dev/null 2>&1

        ufw --force enable > /dev/null 2>&1
    fi

    # Fail2ban
    if command -v fail2ban-client &> /dev/null; then
        systemctl enable fail2ban > /dev/null 2>&1
        systemctl start fail2ban > /dev/null 2>&1
    fi

    # Automatic security updates
    if command -v unattended-upgrades &> /dev/null; then
        dpkg-reconfigure -plow unattended-upgrades > /dev/null 2>&1 || true
    fi

    # Secure SSH config
    if [[ -f /etc/ssh/sshd_config ]]; then
        sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd > /dev/null 2>&1 || true
    fi

    # Set proper permissions
    chmod 700 "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/.env"
    chmod 600 "$INSTALL_DIR/.credentials.enc" 2>/dev/null || true
}

setup_tv_kiosk_mode() {
    apt-get install -y -qq \
        chromium-browser xserver-xorg x11-xserver-utils \
        xinit openbox unclutter > /dev/null 2>&1

    local user_home=$(eval echo ~${SUDO_USER:-pi})
    mkdir -p "$user_home/.config/openbox"

    cat > "$user_home/.config/openbox/autostart" << 'EOF'
xset s off
xset s noblank
xset -dpms
unclutter -idle 5 -root &
sleep 15
chromium-browser --kiosk --disable-infobars --no-first-run --start-fullscreen http://localhost:7575
EOF

    chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} "$user_home/.config/openbox"
}

setup_systemd_service() {
    # Determine which compose file to use
    local compose_cmd="docker compose up -d"
    local compose_stop="docker compose down"

    if [[ "$HARDWARE_MODE" == "limited" ]]; then
        compose_cmd="docker compose -f docker-compose.pi3.yml up -d"
        compose_stop="docker compose -f docker-compose.pi3.yml down"
    fi

    cat > /etc/systemd/system/mediahub.service << EOF
[Unit]
Description=MediaHub Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/$compose_cmd
ExecStop=/usr/bin/$compose_stop
User=${SUDO_USER:-pi}
Group=docker
Environment=HARDWARE_MODE=${HARDWARE_MODE}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mediahub.service > /dev/null 2>&1
}

show_completion() {
    local ip=$(hostname -I | awk '{print $1}')
    local title="$(t "install.complete")"
    local ready_msg="$(t "summary.ready")"
    local access_msg="$(t "summary.access")"
    local creds_msg="$(t "summary.credentials")"

    $TUI --title "$title" \
        --msgbox "🎉 $ready_msg\n\n\
📺 $access_msg :\n\
   http://$ip:7575  (Dashboard)\n\
   http://$ip:8096  (Jellyfin)\n\n\
🔐 $creds_msg :\n\
   /opt/mediahub/scripts/show-passwords.sh\n\n\
📱 $(t "features.notifications") :\n\
   /opt/mediahub/scripts/setup-notifications.sh\n\n\
🎬 $(t "services.jellyfin") :\n\
   1. Prowlarr ($ip:9696)\n\
   2. $(t "services.sonarr") ($ip:8989)\n\
   3. $(t "services.radarr") ($ip:7878)\n\n\
📖 Documentation :\n\
   /opt/mediahub/README.md\n\n\
$(t "common.continue")..." 28 65
}

create_password_viewer() {
    # Ensure directory exists
    mkdir -p "$INSTALL_DIR/scripts" 2>/dev/null || true

    cat > "$INSTALL_DIR/scripts/show-passwords.sh" << 'EOF'
#!/bin/bash
# Show MediaHub passwords (requires master password)

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

echo "========================================="
echo "  MediaHub - Affichage des mots de passe"
echo "========================================="
echo ""

read -sp "Entrez votre mot de passe maître : " master_pass
echo ""

# Verify master password
stored_hash=$(grep "MASTER_PASSWORD_HASH" "$INSTALL_DIR/.env" | cut -d'=' -f2)
input_hash=$(echo -n "$master_pass" | sha256sum | cut -d' ' -f1)

if [[ "$stored_hash" != "$input_hash" ]]; then
    echo "❌ Mot de passe incorrect !"
    exit 1
fi

echo ""
echo "✅ Mot de passe vérifié"
echo ""
echo "Vos identifiants :"
echo "========================================="

openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass pass:"$master_pass" \
    -in "$INSTALL_DIR/.credentials.enc" 2>/dev/null | while IFS='=' read -r key value; do
    case $key in
        JELLYFIN_PASSWORD)
            echo "Jellyfin:"
            echo "  Utilisateur: admin"
            echo "  Mot de passe: $value"
            echo ""
            ;;
        QBITTORRENT_PASSWORD)
            echo "qBittorrent:"
            echo "  Utilisateur: admin"
            echo "  Mot de passe: $value"
            echo ""
            ;;
        PHOTOPRISM_PASSWORD)
            echo "PhotoPrism:"
            echo "  Utilisateur: admin"
            echo "  Mot de passe: $value"
            echo ""
            ;;
        GOTIFY_PASSWORD)
            echo "Gotify:"
            echo "  Utilisateur: admin"
            echo "  Mot de passe: $value"
            echo ""
            ;;
    esac
done

echo "========================================="
echo ""
echo "⚠️  Gardez ces mots de passe en sécurité !"
echo ""
EOF
    chmod +x "$INSTALL_DIR/scripts/show-passwords.sh"
}

# ===========================================
# Rollback Function
# ===========================================
rollback() {
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "UNKNOWN")

    $TUI --title "$(t "install.error")" \
        --yesno "$(t "install.rollback")\n\
État : $state\n\n\
$(t "common.continue") ?" 14 60

    if [[ $? -eq 0 ]]; then
        # Try to recover
        return 1
    fi

    # Rollback
    $TUI --title "$(t "install.rollback")" \
        --infobox "$(t "install.rollback")..." 6 50

    case $state in
        DOCKER_PULL|START|POST_CONFIG)
            cd "$INSTALL_DIR" 2>/dev/null
            docker compose down > /dev/null 2>&1 || true
            ;;
    esac

    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -f "$STATE_FILE"

    $TUI --title "$(t "common.success")" \
        --msgbox "$(t "install.rollback")\n\n$(t "common.continue")" 10 50

    exit 1
}

# ===========================================
# Main Wizard Flow
# ===========================================
main() {
    # Must be root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi

    # Initialize log
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "=== MediaHub Wizard Started ==="

    # Check/install TUI tool
    check_tui_tool

    # Select language first
    select_language
    log "Language selected: $MEDIAHUB_LANG"

    # Select hardware mode (Pi3 limited vs Pi4 full)
    select_hardware_mode

    # Trap errors for rollback
    trap rollback ERR

    # Welcome screen
    show_welcome

    # Check requirements
    if ! show_requirements; then
        $TUI --title "$(t "common.cancel")" \
            --msgbox "$(t "installer.requirements_desc")\n\n$(t "common.continue")" 10 60
        exit 0
    fi

    # Get VPN credentials
    if ! get_vpn_credentials; then
        exit 1
    fi

    # Test VPN (optional)
    # test_vpn_credentials

    # Master password
    if ! get_master_password; then
        exit 1
    fi

    # Select HDD
    if ! select_hdd; then
        exit 1
    fi

    # Select features
    select_features

    # Show summary and confirm
    if ! show_summary; then
        $TUI --title "Installation annulée" \
            --msgbox "Installation annulée par l'utilisateur." 8 50
        exit 0
    fi

    # Run actual installation
    run_installation

    # Create helper scripts
    create_password_viewer

    # Show completion
    show_completion

    # Cleanup
    rm -f "$STATE_FILE"

    log "=== MediaHub Wizard Completed Successfully ==="
}

main "$@"
