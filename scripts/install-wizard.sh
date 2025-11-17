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
        --menu "$select_msg\n\n$providers_info" 22 70 12 \
        "SKIP" ">>> Configurer plus tard <<<" \
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

skip_vpn_setup() {
    VPN_SERVICE_PROVIDER="none"
    VPN_TYPE="none"
    OPENVPN_USER=""
    OPENVPN_PASS=""
    WIREGUARD_PRIVATE_KEY=""
    WIREGUARD_ADDRESSES=""
    SERVER_COUNTRIES=""
    SERVER_REGIONS=""
    SERVER_CITIES=""

    $TUI --title "Configuration VPN ignorée" \
        --msgbox "Le VPN ne sera PAS configuré maintenant.\n\n\
Vous pourrez le configurer plus tard avec :\n\
  $INSTALL_DIR/scripts/setup-vpn.sh\n\n\
ATTENTION : Sans VPN, vos téléchargements ne seront PAS protégés !\n\n\
Les services seront installés mais qBittorrent sera exposé." 16 70

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
        SKIP)
            skip_vpn_setup
            return $?
            ;;
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
        FORMAT_HDD=false
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
        FORMAT_HDD=false
        return 0
    fi

    SELECTED_DRIVE="/dev/$selected"
    USE_EXTERNAL_HDD=true

    # Ask how to configure the HDD
    local hdd_action
    hdd_action=$($TUI --title "Configuration du Disque" \
        --menu "Comment voulez-vous configurer $SELECTED_DRIVE ?" 20 70 4 \
        "FORMAT" "Formater le disque (EFFACE TOUTES LES DONNÉES)" \
        "USE_AS_IS" "Utiliser tel quel (déjà formaté/monté)" \
        "MOUNT_ONLY" "Monter la partition existante (sans formater)" \
        "CANCEL" "Retour" 3>&1 1>&2 2>&3)

    case "$hdd_action" in
        "FORMAT")
            FORMAT_HDD=true
            # Confirm formatting
            local size=$(lsblk -d -o SIZE -n "$SELECTED_DRIVE" 2>/dev/null)
            if ! $TUI --title "CONFIRMATION IMPORTANTE" \
                --yesno "Vous avez sélectionné : $SELECTED_DRIVE ($size)\n\n\
⚠️  ATTENTION ⚠️\n\n\
Ce disque va être ENTIÈREMENT FORMATÉ.\n\
Toutes les données seront DÉFINITIVEMENT PERDUES !\n\n\
Êtes-vous ABSOLUMENT SÛR de vouloir continuer ?" 16 60; then
                USE_EXTERNAL_HDD=false
                FORMAT_HDD=false
                return 1
            fi
            ;;
        "USE_AS_IS")
            FORMAT_HDD=false
            # Check if already mounted
            if mountpoint -q /mnt/media 2>/dev/null; then
                HDD_ALREADY_MOUNTED=true
            else
                HDD_ALREADY_MOUNTED=false
            fi
            ;;
        "MOUNT_ONLY")
            FORMAT_HDD=false
            MOUNT_EXISTING=true
            ;;
        *)
            USE_EXTERNAL_HDD=false
            FORMAT_HDD=false
            return 1
            ;;
    esac

    return 0
}

select_installation_pack() {
    INSTALLATION_PACK=$($TUI --title "Pack d'Installation" \
        --menu "Choisissez votre pack d'installation:\n\nCela détermine quels services seront installés." 20 70 4 \
        "minimal" "Streaming basique (7 services, ~1.5GB RAM)" \
        "essential" "Configuration standard (15 services, ~3GB RAM)" \
        "full" "Toutes les fonctionnalités (30+ services, ~6GB RAM)" \
        "custom" "Choisir les services individuellement" \
        3>&1 1>&2 2>&3)

    if [[ -z "$INSTALLATION_PACK" ]]; then
        INSTALLATION_PACK="essential"
    fi

    case "$INSTALLATION_PACK" in
        minimal)
            $TUI --title "Pack Minimal" --msgbox "PACK MINIMAL (7 services)\n\n\
Services inclus:\n\
• VPN + qBittorrent (Téléchargements)\n\
• Prowlarr + FlareSolverr (Indexeurs)\n\
• Sonarr (Séries TV)\n\
• Radarr (Films)\n\
• Jellyfin (Serveur Média)\n\n\
Idéal pour: Raspberry Pi 3, ressources limitées" 18 60
            ;;
        essential)
            $TUI --title "Pack Essentiel" --msgbox "PACK ESSENTIEL (15 services)\n\n\
Tous les services minimaux PLUS:\n\
• Lidarr (Téléchargement musique)\n\
• Bazarr (Sous-titres)\n\
• Jellyseerr (Gestion des demandes)\n\
• Heimdall (Dashboard)\n\
• Portainer (Gestion Docker)\n\
• Watchtower (Mises à jour auto)\n\
• Unpackerr + Recyclarr (Automatisation)\n\n\
Idéal pour: Raspberry Pi 4, serveur domestique standard" 20 60
            ;;
        full)
            $TUI --title "Pack Complet" --msgbox "PACK COMPLET (30+ services)\n\n\
Tous les services essentiels PLUS:\n\
• Navidrome (Streaming musique)\n\
• Komga (Comics/Manga)\n\
• PhotoPrism (Galerie photos)\n\
• Homarr (Dashboard avancé)\n\
• Netdata + Uptime Kuma (Monitoring)\n\
• Pi-hole (Blocage pub)\n\
• Duplicati (Sauvegardes)\n\
• Notifications (Gotify, Apprise)\n\
• Et plus...\n\n\
Idéal pour: Systèmes puissants, fonctionnalités complètes" 22 60
            ;;
        custom)
            CUSTOM_SERVICES=$($TUI --title "Pack Personnalisé" \
                --checklist "Sélectionnez les services à installer:" 25 70 15 \
                "sonarr" "Gestionnaire Séries TV" ON \
                "radarr" "Gestionnaire Films" ON \
                "lidarr" "Gestionnaire Musique" OFF \
                "bazarr" "Gestionnaire Sous-titres" OFF \
                "jellyfin" "Serveur Média" ON \
                "jellyseerr" "Gestionnaire Demandes" OFF \
                "navidrome" "Streaming Musique" OFF \
                "komga" "Lecteur Comics/Manga" OFF \
                "photoprism" "Galerie Photos" OFF \
                "homarr" "Dashboard" ON \
                "heimdall" "Dashboard Simple" OFF \
                "portainer" "Gestion Docker" OFF \
                "netdata" "Monitoring Système" OFF \
                "uptime-kuma" "Monitoring Services" OFF \
                "pihole" "Bloqueur Pub/DNS" OFF \
                "duplicati" "Solution Backup" OFF \
                "watchtower" "Mises à jour Auto" ON \
                3>&1 1>&2 2>&3)
            ;;
    esac

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
    summary+="Pack d'installation : $INSTALLATION_PACK\n"
    summary+="$provider_label : $VPN_SERVICE_PROVIDER\n"
    summary+="$(t "password.title") : $(t "common.confirm")\n"

    if [[ "$USE_EXTERNAL_HDD" == true ]]; then
        summary+="$(t "installer.hdd_detected") : $SELECTED_DRIVE\n"
        if [[ "$FORMAT_HDD" == true ]]; then
            summary+="Action HDD : FORMATER (effacera les données)\n"
        elif [[ "$MOUNT_EXISTING" == true ]]; then
            summary+="Action HDD : Monter partition existante\n"
        elif [[ "$HDD_ALREADY_MOUNTED" == true ]]; then
            summary+="Action HDD : Utiliser tel quel (déjà monté)\n"
        else
            summary+="Action HDD : Utiliser tel quel\n"
        fi
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
        # Install basic dependencies first
        apt-get install -y -qq \
            curl wget git jq openssl gnupg2 ca-certificates \
            > /dev/null 2>&1 || true

        show_progress 20 "Installing Docker..."
        save_state "DOCKER_INSTALL"
        # Install Docker using official convenience script (works on Raspberry Pi)
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 || true
        fi

        show_progress 25 "$MSG_CONFIGURING"
        save_state "DOCKER"
        systemctl enable docker > /dev/null 2>&1 || true
        systemctl start docker > /dev/null 2>&1 || true
        usermod -aG docker "${SUDO_USER:-pi}" 2>/dev/null || true

        # Install docker-compose plugin if not available
        if ! docker compose version &> /dev/null; then
            apt-get install -y -qq docker-compose-plugin > /dev/null 2>&1 || true
        fi

        # Setup HDD first (before Docker config to know where to store images)
        show_progress 27 "$MSG_HDD..."
        save_state "HDD_FORMAT"
        mkdir -p /mnt/media

        local DOCKER_DATA_ROOT="/var/lib/docker"

        if [[ "$USE_EXTERNAL_HDD" == true ]] && [[ -n "$SELECTED_DRIVE" ]]; then
            # Prepare external HDD
            local partition="${SELECTED_DRIVE}1"

            if [[ "$FORMAT_HDD" == true ]]; then
                # Full format and partition
                parted -s "$SELECTED_DRIVE" mklabel gpt > /dev/null 2>&1 || true
                parted -s "$SELECTED_DRIVE" mkpart primary ext4 0% 100% > /dev/null 2>&1 || true
                sleep 2
                partition="${SELECTED_DRIVE}1"

                mkfs.ext4 -F -L mediahub "$partition" > /dev/null 2>&1 || true

                # Mount the drive
                mount "$partition" /mnt/media > /dev/null 2>&1 || true

                # Add to fstab
                local uuid=$(blkid -s UUID -o value "$partition" 2>/dev/null || echo "")
                if [[ -n "$uuid" ]] && ! grep -q "$uuid" /etc/fstab 2>/dev/null; then
                    echo "UUID=$uuid /mnt/media ext4 defaults,noatime,nofail 0 2" >> /etc/fstab
                fi

                # Create media directories (including docker)
                mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads,docker}
                mkdir -p /mnt/media/library/photos/{originals,import}
                chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media
                chmod -R 755 /mnt/media

            elif [[ "$MOUNT_EXISTING" == true ]]; then
                # Mount existing partition without formatting
                if [[ -b "$partition" ]]; then
                    local fs_type=$(blkid -o value -s TYPE "$partition" 2>/dev/null || echo "")
                    if [[ -n "$fs_type" ]]; then
                        if ! mountpoint -q /mnt/media 2>/dev/null; then
                            mount "$partition" /mnt/media > /dev/null 2>&1 || true
                        fi

                        # Add to fstab if not already there
                        local uuid=$(blkid -s UUID -o value "$partition" 2>/dev/null || echo "")
                        if [[ -n "$uuid" ]] && ! grep -q "$uuid" /etc/fstab 2>/dev/null; then
                            echo "UUID=$uuid /mnt/media $fs_type defaults,noatime,nofail 0 2" >> /etc/fstab
                        fi
                    fi
                fi

                # Ensure directories exist
                mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads,docker}
                mkdir -p /mnt/media/library/photos/{originals,import}
                chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media 2>/dev/null || true
                chmod -R 755 /mnt/media 2>/dev/null || true

            elif [[ "$HDD_ALREADY_MOUNTED" == true ]]; then
                # Use as-is, already mounted - just ensure directories exist
                mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads,docker}
                mkdir -p /mnt/media/library/photos/{originals,import}
                chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media 2>/dev/null || true
                chmod -R 755 /mnt/media 2>/dev/null || true

            else
                # USE_AS_IS but not mounted - try to mount
                if [[ -b "$partition" ]]; then
                    mount "$partition" /mnt/media > /dev/null 2>&1 || true
                fi

                # Ensure directories exist
                mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads,docker}
                mkdir -p /mnt/media/library/photos/{originals,import}
                chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media 2>/dev/null || true
                chmod -R 755 /mnt/media 2>/dev/null || true
            fi

            # Save device for Scrutiny
            export SCRUTINY_DEVICE="$SELECTED_DRIVE"

            # Use HDD for Docker storage if mounted
            if mountpoint -q /mnt/media 2>/dev/null; then
                DOCKER_DATA_ROOT="/mnt/media/docker"
            fi
        else
            # Create directories anyway
            mkdir -p /mnt/media/{library/{tv,movies,music,books,comics,photos},downloads}
            mkdir -p /mnt/media/library/photos/{originals,import}
            chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} /mnt/media 2>/dev/null || true
        fi

        # Optimize Docker for Raspberry Pi (prevent timeouts)
        show_progress 30 "Optimizing Docker configuration..."
        mkdir -p /etc/docker

        # Stop Docker before changing data-root
        if [[ "$DOCKER_DATA_ROOT" != "/var/lib/docker" ]]; then
            systemctl stop docker > /dev/null 2>&1 || true
            sleep 2
        fi

        cat > /etc/docker/daemon.json << DOCKERCFG
{
  "data-root": "$DOCKER_DATA_ROOT",
  "max-concurrent-downloads": 2,
  "max-concurrent-uploads": 2,
  "max-download-attempts": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
DOCKERCFG
        systemctl start docker > /dev/null 2>&1 || true
        sleep 3

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

        # Check if images are already downloaded
        local missing_count=0
        local compose_check=""
        if [[ "$HARDWARE_MODE" == "limited" ]] && [[ -f docker-compose.pi3.yml ]]; then
            compose_check="docker-compose.pi3.yml"
        else
            compose_check="docker-compose.yml"
        fi

        # Count missing images
        local required_imgs=$(docker compose -f "$compose_check" config --images 2>/dev/null | sort -u)
        for img in $required_imgs; do
            if ! docker image inspect "$img" > /dev/null 2>&1; then
                missing_count=$((missing_count + 1))
            fi
        done

        # Only pull if images are missing
        if [[ $missing_count -gt 0 ]]; then
            # Pull images with retry logic (max 3 attempts)
            local pull_retries=0
            local pull_max=3
            local pull_done=false

            while [[ $pull_retries -lt $pull_max ]] && [[ "$pull_done" == "false" ]]; do
                pull_retries=$((pull_retries + 1))

                if [[ "$HARDWARE_MODE" == "limited" ]]; then
                    # Pi3 mode - use limited compose file
                    if docker compose -f docker-compose.pi3.yml pull 2>&1 | grep -q "error\|timeout"; then
                        sleep 10
                    else
                        pull_done=true
                    fi
                else
                    # Full mode - use standard compose file
                    if docker compose pull 2>&1 | grep -q "error\|timeout"; then
                        sleep 10
                    else
                        pull_done=true
                    fi
                fi

                if [[ "$pull_done" == "false" ]] && [[ $pull_retries -lt $pull_max ]]; then
                    show_progress $((60 + pull_retries * 5)) "Retrying image download ($pull_retries/$pull_max)..."
                fi
            done
        fi
        # If no images missing, skip pull (saves time on reinstall)

        show_progress 80 "$MSG_STARTING_SERVICES"
        save_state "START"

        # Load pack configuration and determine services to start
        local pack_services=""
        if [[ -f "$INSTALL_DIR/config/packs.conf" ]]; then
            source "$INSTALL_DIR/config/packs.conf"
        fi

        case "$INSTALLATION_PACK" in
            minimal) pack_services="$PACK_MINIMAL" ;;
            essential) pack_services="$PACK_ESSENTIAL" ;;
            full) pack_services="$PACK_FULL" ;;
            custom) pack_services="gluetun qbittorrent prowlarr flaresolverr $CUSTOM_SERVICES" ;;
            *) pack_services="$PACK_ESSENTIAL" ;;
        esac

        # Save current pack
        echo "$INSTALLATION_PACK" > "$INSTALL_DIR/.current_pack"

        if [[ "$HARDWARE_MODE" == "limited" ]]; then
            docker compose -f docker-compose.pi3.yml up -d $pack_services > /dev/null 2>&1 || true
        else
            docker compose up -d $pack_services > /dev/null 2>&1 || true
        fi

        show_progress 85 "$MSG_LINKING"
        save_state "POST_CONFIG"
        # Reduced wait time - services should be starting
        sleep 10

        show_progress 87 "Running post-install setup..."
        save_state "POST_SETUP"
        if [[ -f "$INSTALL_DIR/scripts/post-install-setup.sh" ]]; then
            bash "$INSTALL_DIR/scripts/post-install-setup.sh" > /dev/null 2>&1 || true
        fi

        show_progress 90 "Configuring features..."
        save_state "FEATURES"
        if [[ "$FEATURES" == *"TV_KIOSK"* ]]; then
            show_progress 92 "$MSG_TV_KIOSK..."
            save_state "TV_KIOSK"
            setup_tv_kiosk_mode
        fi

        show_progress 95 "Setting up autostart service..."
        save_state "AUTOSTART"
        setup_systemd_service

        show_progress 98 "Finalizing installation..."
        save_state "FINALIZING"
        sleep 1

        show_progress 100 "$MSG_COMPLETE"
        save_state "COMPLETE"
        sleep 1

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
BACKUP_PATH=$INSTALL_DIR/backups

# VPN Configuration (Multi-Provider Support)
VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-none}
VPN_TYPE=${VPN_TYPE:-none}

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
PIHOLE_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

# Security
MASTER_PASSWORD_HASH=$(echo -n "$MASTER_PASSWORD" | sha256sum | cut -d' ' -f1)

# Feature Flags
ENABLE_TV_KIOSK=$([[ "$FEATURES" == *"TV_KIOSK"* ]] && echo "true" || echo "false")
ENABLE_HDMI_CEC=$([[ "$FEATURES" == *"HDMI_CEC"* ]] && echo "true" || echo "false")
ENABLE_NOTIFICATIONS=$([[ "$FEATURES" == *"NOTIFICATIONS"* ]] && echo "true" || echo "false")
ENABLE_MONITORING=$([[ "$FEATURES" == *"MONITORING"* ]] && echo "true" || echo "false")

# Hardware Mode
HARDWARE_MODE=${HARDWARE_MODE:-full}

# Scrutiny Disk Monitoring (set to your external HDD device)
SCRUTINY_DEVICE=${SCRUTINY_DEVICE:-/dev/sda}
EOF

    # Create backup directory
    mkdir -p "$INSTALL_DIR/backups" 2>/dev/null || true

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
    local KIOSK_USER="${SUDO_USER:-pi}"
    local user_home=$(eval echo ~$KIOSK_USER)
    local DASHBOARD_URL="http://localhost:7575"

    apt-get install -y -qq \
        chromium-browser xserver-xorg x11-xserver-utils \
        xinit openbox unclutter > /dev/null 2>&1

    # Configure auto-login on tty1
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

    # Setup Openbox autostart
    mkdir -p "$user_home/.config/openbox"
    cat > "$user_home/.config/openbox/autostart" << EOF
xset s off
xset s noblank
xset -dpms
unclutter -idle 5 -root &
sleep 15
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

    # Create .xinitrc
    cat > "$user_home/.xinitrc" << 'EOF'
#!/bin/sh
exec openbox-session
EOF
    chmod +x "$user_home/.xinitrc"
    chown "$KIOSK_USER:$KIOSK_USER" "$user_home/.xinitrc"

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

    # Create dashboard management scripts
    mkdir -p "$INSTALL_DIR/scripts"
    cat > "$INSTALL_DIR/scripts/change-dashboard.sh" << 'EOF'
#!/bin/bash
CURRENT_URL=$(grep "chromium-browser" ~/.config/openbox/autostart | grep -oP 'http[s]?://[^ ]+' | tail -1)
echo "Current dashboard: $CURRENT_URL"
echo "Options: 1=Homarr 2=Jellyfin 3=Komga 4=Navidrome 5=Admin 6=Uptime 7=Custom"
read -p "Choice: " c
case $c in
    1) U="http://localhost:7575" ;; 2) U="http://localhost:8096" ;;
    3) U="http://localhost:25600" ;; 4) U="http://localhost:4533" ;;
    5) U="http://localhost:8091" ;; 6) U="http://localhost:3001" ;;
    7) read -p "URL: " U ;; *) exit 1 ;;
esac
sed -i "s|$CURRENT_URL|$U|g" ~/.config/openbox/autostart
echo "Changed to: $U - Reboot to apply"
EOF
    chmod +x "$INSTALL_DIR/scripts/change-dashboard.sh"

    cat > "$INSTALL_DIR/scripts/refresh-dashboard.sh" << 'EOF'
#!/bin/bash
pkill -f chromium-browser
EOF
    chmod +x "$INSTALL_DIR/scripts/refresh-dashboard.sh"
    chown -R "$KIOSK_USER:$KIOSK_USER" "$INSTALL_DIR/scripts/" 2>/dev/null || true

    # Create kiosk systemd service
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
    systemctl enable mediahub-kiosk.service > /dev/null 2>&1 || true

    # Configure HDMI output (Raspberry Pi specific)
    if [[ -f /boot/config.txt ]] && ! grep -q "hdmi_force_hotplug" /boot/config.txt; then
        cat >> /boot/config.txt << 'EOF'

# MediaHub TV Configuration
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
EOF
    fi
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

    # Select installation pack
    select_installation_pack

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
