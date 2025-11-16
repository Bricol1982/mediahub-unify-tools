#!/bin/bash
# MediaHub VPN Configuration Wizard
# Supports 24+ VPN providers via Gluetun
# Multi-language support

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Language support
MEDIAHUB_LANG="${MEDIAHUB_LANG:-fr}"
declare -gA TRANSLATIONS

# Load translations
load_i18n() {
    # Check for saved language preference
    if [[ -f "${HOME}/.mediahub_lang" ]]; then
        source "${HOME}/.mediahub_lang"
    fi

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

# Load translations at startup
load_i18n

# All Gluetun supported providers
declare -A VPN_PROVIDERS=(
    ["airvpn"]="AirVPN"
    ["cyberghost"]="CyberGhost"
    ["expressvpn"]="ExpressVPN"
    ["fastestvpn"]="FastestVPN"
    ["hidemyass"]="HideMyAss"
    ["ipvanish"]="IPVanish"
    ["ivpn"]="IVPN"
    ["mullvad"]="Mullvad"
    ["nordvpn"]="NordVPN"
    ["perfectprivacy"]="Perfect Privacy"
    ["privado"]="Privado"
    ["privatevpn"]="PrivateVPN"
    ["protonvpn"]="ProtonVPN"
    ["purevpn"]="PureVPN"
    ["pia"]="Private Internet Access (PIA)"
    ["surfshark"]="Surfshark"
    ["torguard"]="TorGuard"
    ["vpnsecure"]="VPN Secure"
    ["vpnunlimited"]="VPN Unlimited"
    ["vyprvpn"]="VyprVPN"
    ["wevpn"]="WeVPN"
    ["windscribe"]="Windscribe"
    ["custom"]="Custom (OpenVPN/Wireguard)"
)

# Provider-specific configuration requirements
get_provider_config() {
    local provider="$1"

    case "$provider" in
        airvpn)
            echo "DEVICE_TYPE|VPN_ENDPOINT_IP|VPN_ENDPOINT_PORT|WIREGUARD_PRIVATE_KEY|WIREGUARD_PRESHARED_KEY|WIREGUARD_ADDRESSES"
            ;;
        cyberghost)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        expressvpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        fastestvpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        hidemyass)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        ipvanish)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        ivpn)
            echo "OPENVPN_USER|WIREGUARD_PRIVATE_KEY|WIREGUARD_ADDRESSES|SERVER_COUNTRIES"
            ;;
        mullvad)
            echo "WIREGUARD_PRIVATE_KEY|WIREGUARD_ADDRESSES|SERVER_CITIES"
            ;;
        nordvpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        perfectprivacy)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        privado)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        privatevpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        protonvpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        purevpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        pia)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_REGIONS"
            ;;
        surfshark)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        torguard)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        vpnsecure)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        vpnunlimited)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        vyprvpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        wevpn)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        windscribe)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
        custom)
            echo "CUSTOM_CONFIG"
            ;;
        *)
            echo "OPENVPN_USER|OPENVPN_PASSWORD|SERVER_COUNTRIES"
            ;;
    esac
}

show_header() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  MediaHub VPN Configuration${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Check if whiptail is available
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        echo -e "${RED}whiptail n'est pas installé !${NC}"
        echo "Installation: sudo apt install whiptail"
        exit 1
    fi
}

# Select VPN provider using whiptail
select_provider() {
    local options=()
    local title="$(t "vpn.select_provider")"

    # Build options array for whiptail
    options+=("protonvpn" "ProtonVPN (Recommandé)")
    options+=("mullvad" "Mullvad (Vie privée)")
    options+=("nordvpn" "NordVPN (Populaire)")
    options+=("surfshark" "Surfshark (Économique)")
    options+=("pia" "Private Internet Access")
    options+=("expressvpn" "ExpressVPN")
    options+=("cyberghost" "CyberGhost")
    options+=("ivpn" "IVPN")
    options+=("windscribe" "Windscribe")
    options+=("airvpn" "AirVPN (Wireguard)")
    options+=("ipvanish" "IPVanish")
    options+=("vyprvpn" "VyprVPN")
    options+=("purevpn" "PureVPN")
    options+=("privatevpn" "PrivateVPN")
    options+=("torguard" "TorGuard")
    options+=("hidemyass" "HideMyAss")
    options+=("fastestvpn" "FastestVPN")
    options+=("perfectprivacy" "Perfect Privacy")
    options+=("privado" "Privado")
    options+=("vpnsecure" "VPN Secure")
    options+=("vpnunlimited" "VPN Unlimited")
    options+=("wevpn" "WeVPN")
    options+=("custom" "Configuration Personnalisée")

    local provider
    provider=$(whiptail --title "$title" \
        --menu "$(t "vpn.providers_info")" 25 70 16 \
        "${options[@]}" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        echo ""
        return 1
    fi

    echo "$provider"
}

# Get provider-specific credentials
configure_provider() {
    local provider="$1"
    local config_requirements
    config_requirements=$(get_provider_config "$provider")

    # Initialize variables
    VPN_USER=""
    VPN_PASS=""
    VPN_COUNTRY="Netherlands"
    VPN_REGION=""
    VPN_CITY=""
    WG_PRIVATE_KEY=""
    WG_ADDRESSES=""
    WG_PRESHARED_KEY=""
    CUSTOM_CONFIG_TYPE=""
    CUSTOM_CONFIG_PATH=""

    case "$provider" in
        protonvpn|nordvpn|expressvpn|surfshark|cyberghost|ipvanish|vyprvpn|purevpn|privatevpn|torguard|hidemyass|fastestvpn|perfectprivacy|privado|vpnsecure|vpnunlimited|wevpn|windscribe)
            configure_openvpn_provider "$provider"
            ;;
        mullvad)
            configure_mullvad
            ;;
        airvpn)
            configure_airvpn
            ;;
        ivpn)
            configure_ivpn
            ;;
        pia)
            configure_pia
            ;;
        custom)
            configure_custom
            ;;
    esac
}

configure_openvpn_provider() {
    local provider="$1"
    local provider_name="${VPN_PROVIDERS[$provider]}"
    local username_label="$(t "vpn.username")"
    local password_label="$(t "vpn.password")"
    local country_label="$(t "vpn.server_country")"
    local warning_msg="$(t "vpn.credentials_warning")"

    # Get username
    VPN_USER=$(whiptail --title "$provider_name - $username_label" \
        --inputbox "$(t "vpn.username") $provider_name :\n\n$warning_msg" 12 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$VPN_USER" ]]; then
        return 1
    fi

    # Get password
    VPN_PASS=$(whiptail --title "$provider_name - $password_label" \
        --passwordbox "$(t "vpn.password") $provider_name :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$VPN_PASS" ]]; then
        return 1
    fi

    # Get country
    VPN_COUNTRY=$(whiptail --title "$provider_name - $country_label" \
        --inputbox "$country_label :\n\nExemples: Netherlands, Switzerland, Sweden, Germany" 12 70 "Netherlands" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    return 0
}

configure_mullvad() {
    whiptail --title "Mullvad - Configuration Wireguard" \
        --msgbox "Mullvad utilise Wireguard.\n\nVous aurez besoin de :\n1. Votre clé privée Wireguard\n2. Vos adresses IP Wireguard\n\nTrouvez ces informations dans votre compte Mullvad\nsous 'Wireguard configuration'." 14 70

    WG_PRIVATE_KEY=$(whiptail --title "Mullvad - Clé Privée" \
        --inputbox "Entrez votre clé privée Wireguard Mullvad :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$WG_PRIVATE_KEY" ]]; then
        return 1
    fi

    WG_ADDRESSES=$(whiptail --title "Mullvad - Adresses IP" \
        --inputbox "Entrez vos adresses Wireguard (séparées par des virgules) :\n\nExemple: 10.64.0.1/32" 12 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$WG_ADDRESSES" ]]; then
        return 1
    fi

    VPN_CITY=$(whiptail --title "Mullvad - Ville" \
        --inputbox "Ville du serveur (optionnel) :\n\nExemples: amsterdam, zurich, stockholm\nLaissez vide pour auto-sélection" 12 70 3>&1 1>&2 2>&3)

    return 0
}

configure_airvpn() {
    whiptail --title "AirVPN - Configuration Wireguard" \
        --msgbox "AirVPN supporte Wireguard.\n\nVous aurez besoin de :\n1. Votre clé privée Wireguard\n2. Clé pré-partagée\n3. Adresses IP\n4. IP et port du serveur\n\nTrouvez ces informations dans votre compte AirVPN." 16 70

    WG_PRIVATE_KEY=$(whiptail --title "AirVPN - Clé Privée" \
        --inputbox "Entrez votre clé privée Wireguard :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$WG_PRIVATE_KEY" ]]; then
        return 1
    fi

    WG_PRESHARED_KEY=$(whiptail --title "AirVPN - Clé Pré-partagée" \
        --inputbox "Entrez votre clé pré-partagée :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    WG_ADDRESSES=$(whiptail --title "AirVPN - Adresses" \
        --inputbox "Entrez vos adresses Wireguard :\n\nExemple: 10.128.0.1/32" 12 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$WG_ADDRESSES" ]]; then
        return 1
    fi

    VPN_ENDPOINT_IP=$(whiptail --title "AirVPN - IP Serveur" \
        --inputbox "Entrez l'IP du serveur AirVPN :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$VPN_ENDPOINT_IP" ]]; then
        return 1
    fi

    VPN_ENDPOINT_PORT=$(whiptail --title "AirVPN - Port" \
        --inputbox "Entrez le port du serveur :" 10 70 "1637" 3>&1 1>&2 2>&3)

    return 0
}

configure_ivpn() {
    local auth_method
    auth_method=$(whiptail --title "IVPN - Méthode d'authentification" \
        --menu "Choisissez la méthode :" 12 60 2 \
        "openvpn" "OpenVPN (nom d'utilisateur/mot de passe)" \
        "wireguard" "Wireguard (clé privée)" \
        3>&1 1>&2 2>&3)

    if [[ "$auth_method" == "openvpn" ]]; then
        VPN_USER=$(whiptail --title "IVPN - Nom d'utilisateur" \
            --inputbox "Entrez votre nom d'utilisateur IVPN :" 10 70 3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]] || [[ -z "$VPN_USER" ]]; then
            return 1
        fi
    else
        WG_PRIVATE_KEY=$(whiptail --title "IVPN - Clé Privée Wireguard" \
            --inputbox "Entrez votre clé privée Wireguard :" 10 70 3>&1 1>&2 2>&3)

        WG_ADDRESSES=$(whiptail --title "IVPN - Adresses" \
            --inputbox "Entrez vos adresses Wireguard :" 12 70 3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]] || [[ -z "$WG_PRIVATE_KEY" ]] || [[ -z "$WG_ADDRESSES" ]]; then
            return 1
        fi
    fi

    VPN_COUNTRY=$(whiptail --title "IVPN - Pays" \
        --inputbox "Pays du serveur :" 10 70 "Netherlands" 3>&1 1>&2 2>&3)

    return 0
}

configure_pia() {
    VPN_USER=$(whiptail --title "PIA - Nom d'utilisateur" \
        --inputbox "Entrez votre nom d'utilisateur PIA :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$VPN_USER" ]]; then
        return 1
    fi

    VPN_PASS=$(whiptail --title "PIA - Mot de passe" \
        --passwordbox "Entrez votre mot de passe PIA :" 10 70 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]] || [[ -z "$VPN_PASS" ]]; then
        return 1
    fi

    VPN_REGION=$(whiptail --title "PIA - Région" \
        --inputbox "Région du serveur PIA :\n\nExemples: Netherlands, Switzerland, Sweden" 12 70 "Netherlands" 3>&1 1>&2 2>&3)

    return 0
}

configure_custom() {
    CUSTOM_CONFIG_TYPE=$(whiptail --title "Configuration Personnalisée" \
        --menu "Type de configuration :" 12 60 2 \
        "openvpn" "OpenVPN (.ovpn file)" \
        "wireguard" "Wireguard (.conf file)" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    if [[ "$CUSTOM_CONFIG_TYPE" == "openvpn" ]]; then
        whiptail --title "OpenVPN Personnalisé" \
            --msgbox "Configuration OpenVPN personnalisée :\n\n1. Placez votre fichier .ovpn dans :\n   $PROJECT_DIR/config/gluetun/\n\n2. Renommez-le en : custom.ovpn\n\n3. Si vous avez un fichier d'auth, placez-le aussi\n   et nommez-le : auth.txt\n\nAppuyez sur OK quand c'est fait." 16 70

        # Check if file exists
        if [[ ! -f "$PROJECT_DIR/config/gluetun/custom.ovpn" ]]; then
            whiptail --title "Fichier manquant" \
                --yesno "Le fichier custom.ovpn n'a pas été trouvé.\n\nVoulez-vous continuer quand même ?\n(Vous devrez l'ajouter avant de démarrer)" 12 60

            if [[ $? -ne 0 ]]; then
                return 1
            fi
        fi

        # Ask for auth if needed
        if whiptail --title "Authentification" \
            --yesno "Votre configuration OpenVPN nécessite-t-elle\nun nom d'utilisateur et mot de passe ?" 10 60; then

            VPN_USER=$(whiptail --title "OpenVPN - Nom d'utilisateur" \
                --inputbox "Entrez votre nom d'utilisateur :" 10 70 3>&1 1>&2 2>&3)

            VPN_PASS=$(whiptail --title "OpenVPN - Mot de passe" \
                --passwordbox "Entrez votre mot de passe :" 10 70 3>&1 1>&2 2>&3)
        fi

    else
        whiptail --title "Wireguard Personnalisé" \
            --msgbox "Configuration Wireguard personnalisée :\n\n1. Placez votre fichier .conf dans :\n   $PROJECT_DIR/config/gluetun/\n\n2. Renommez-le en : wg0.conf\n\nAppuyez sur OK quand c'est fait." 14 70

        if [[ ! -f "$PROJECT_DIR/config/gluetun/wg0.conf" ]]; then
            whiptail --title "Fichier manquant" \
                --yesno "Le fichier wg0.conf n'a pas été trouvé.\n\nVoulez-vous continuer quand même ?" 10 60

            if [[ $? -ne 0 ]]; then
                return 1
            fi
        fi
    fi

    return 0
}

# Generate environment variables for the selected provider
generate_env_config() {
    local provider="$1"
    local env_content=""

    echo "# ===========================================
# VPN Configuration (Auto-generated)
# Provider: ${VPN_PROVIDERS[$provider]}
# ===========================================
VPN_SERVICE_PROVIDER=$provider"

    case "$provider" in
        mullvad)
            cat << EOF
WIREGUARD_PRIVATE_KEY=$WG_PRIVATE_KEY
WIREGUARD_ADDRESSES=$WG_ADDRESSES
VPN_TYPE=wireguard
EOF
            if [[ -n "$VPN_CITY" ]]; then
                echo "SERVER_CITIES=$VPN_CITY"
            fi
            ;;
        airvpn)
            cat << EOF
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=$WG_PRIVATE_KEY
WIREGUARD_PRESHARED_KEY=$WG_PRESHARED_KEY
WIREGUARD_ADDRESSES=$WG_ADDRESSES
VPN_ENDPOINT_IP=$VPN_ENDPOINT_IP
VPN_ENDPOINT_PORT=$VPN_ENDPOINT_PORT
EOF
            ;;
        ivpn)
            if [[ -n "$VPN_USER" ]]; then
                cat << EOF
OPENVPN_USER=$VPN_USER
VPN_TYPE=openvpn
SERVER_COUNTRIES=$VPN_COUNTRY
EOF
            else
                cat << EOF
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=$WG_PRIVATE_KEY
WIREGUARD_ADDRESSES=$WG_ADDRESSES
SERVER_COUNTRIES=$VPN_COUNTRY
EOF
            fi
            ;;
        pia)
            cat << EOF
OPENVPN_USER=$VPN_USER
OPENVPN_PASSWORD=$VPN_PASS
SERVER_REGIONS=$VPN_REGION
VPN_TYPE=openvpn
EOF
            ;;
        custom)
            if [[ "$CUSTOM_CONFIG_TYPE" == "openvpn" ]]; then
                cat << EOF
VPN_TYPE=openvpn
OPENVPN_CUSTOM_CONFIG=/gluetun/custom.ovpn
EOF
                if [[ -n "$VPN_USER" ]]; then
                    echo "OPENVPN_USER=$VPN_USER"
                    echo "OPENVPN_PASSWORD=$VPN_PASS"
                fi
            else
                echo "VPN_TYPE=wireguard"
                echo "WIREGUARD_CONF=/gluetun/wg0.conf"
            fi
            ;;
        *)
            # Standard OpenVPN providers
            cat << EOF
OPENVPN_USER=$VPN_USER
OPENVPN_PASSWORD=$VPN_PASS
SERVER_COUNTRIES=$VPN_COUNTRY
VPN_TYPE=openvpn
EOF
            ;;
    esac
}

# Update docker-compose.yml with flexible VPN config
update_docker_compose() {
    local provider="$1"

    # Create a backup
    cp "$PROJECT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml.bak"

    echo -e "${BLUE}Mise à jour de docker-compose.yml...${NC}"

    # The docker-compose will use environment variables from .env
    # We don't need to modify it if it already uses variables

    return 0
}

# Create docker-compose override for VPN configuration
create_vpn_override() {
    local provider="$1"
    local override_file="$PROJECT_DIR/docker-compose.vpn.yml"

    cat > "$override_file" << 'EOF'
version: "3.8"

# VPN Configuration Override
# This file is auto-generated by setup-vpn.sh
# Merge with: docker compose -f docker-compose.yml -f docker-compose.vpn.yml up -d

services:
  gluetun:
    environment:
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER:-protonvpn}
      - VPN_TYPE=${VPN_TYPE:-openvpn}
      # OpenVPN credentials
      - OPENVPN_USER=${OPENVPN_USER:-}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD:-}
      # Wireguard credentials
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY:-}
      - WIREGUARD_PRESHARED_KEY=${WIREGUARD_PRESHARED_KEY:-}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES:-}
      # Server selection
      - SERVER_COUNTRIES=${SERVER_COUNTRIES:-}
      - SERVER_REGIONS=${SERVER_REGIONS:-}
      - SERVER_CITIES=${SERVER_CITIES:-}
      # Custom config
      - OPENVPN_CUSTOM_CONFIG=${OPENVPN_CUSTOM_CONFIG:-}
      # AirVPN specific
      - VPN_ENDPOINT_IP=${VPN_ENDPOINT_IP:-}
      - VPN_ENDPOINT_PORT=${VPN_ENDPOINT_PORT:-}
EOF

    echo -e "${GREEN}✓ Fichier docker-compose.vpn.yml créé${NC}"
}

# Save configuration to .env file
save_config() {
    local provider="$1"
    local env_file="$PROJECT_DIR/.env"
    local temp_file="/tmp/vpn_env_$$"

    # Generate VPN config
    generate_env_config "$provider" > "$temp_file"

    # If .env exists, update it; otherwise create it
    if [[ -f "$env_file" ]]; then
        # Remove old VPN config
        grep -v "^VPN_SERVICE_PROVIDER\|^OPENVPN_USER\|^OPENVPN_PASSWORD\|^WIREGUARD_\|^SERVER_\|^VPN_TYPE\|^VPN_ENDPOINT\|^PROTON_" "$env_file" > "${env_file}.tmp" || true

        # Add new VPN config
        cat "$temp_file" >> "${env_file}.tmp"
        mv "${env_file}.tmp" "$env_file"
    else
        # Copy example and add VPN config
        if [[ -f "$PROJECT_DIR/.env.example" ]]; then
            cp "$PROJECT_DIR/.env.example" "$env_file"
        fi
        cat "$temp_file" >> "$env_file"
    fi

    rm -f "$temp_file"
    chmod 600 "$env_file"

    echo -e "${GREEN}✓ Configuration VPN sauvegardée dans .env${NC}"
}

# Test VPN connection
test_vpn_connection() {
    echo ""
    echo -e "${BLUE}$(t "vpn.test_connection")${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not installed${NC}"
        return 1
    fi

    # Check if gluetun is running
    if docker ps --format '{{.Names}}' | grep -q "^gluetun$"; then
        echo -e "${GREEN}✓ Gluetun running${NC}"

        # Check VPN IP
        local vpn_ip
        vpn_ip=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null || echo "")

        if [[ -n "$vpn_ip" ]]; then
            echo -e "${GREEN}✓ $(t "vpn.test_success")${NC}"
            echo -e "  IP: ${CYAN}$vpn_ip${NC}"

            # Get location
            local location
            location=$(docker exec gluetun wget -qO- "https://ipinfo.io/$vpn_ip/city" 2>/dev/null || echo "")
            if [[ -n "$location" ]]; then
                echo -e "  Location: ${CYAN}$location${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ $(t "vpn.test_failed")${NC}"
        fi
    else
        echo -e "${YELLOW}Gluetun not started${NC}"
        echo "Start with: docker compose up -d gluetun"
    fi
}

# Show summary
show_summary() {
    local provider="$1"
    local title="$(t "common.success")"
    local provider_label="$(t "summary.provider")"

    whiptail --title "$title" \
        --msgbox "$(t "postinstall.complete")\n\n$provider_label: ${VPN_PROVIDERS[$provider]}\n\nFiles:\n- .env (credentials)\n- docker-compose.vpn.yml (override)\n\nNext:\n1. Check .env\n2. Start:\n   docker compose -f docker-compose.yml \\\n     -f docker-compose.vpn.yml up -d\n\nOr:\n   ./scripts/start.sh" 22 70
}

# Non-interactive mode for scripting
run_non_interactive() {
    local provider="$1"
    local user="$2"
    local pass="$3"
    local country="${4:-Netherlands}"

    if [[ -z "$provider" ]] || [[ -z "$user" ]] || [[ -z "$pass" ]]; then
        echo "Usage: $0 --non-interactive <provider> <user> <pass> [country]"
        exit 1
    fi

    VPN_USER="$user"
    VPN_PASS="$pass"
    VPN_COUNTRY="$country"

    save_config "$provider"
    create_vpn_override "$provider"

    echo -e "${GREEN}✓ Configuration VPN complète pour $provider${NC}"
}

# Main function
main() {
    # Check for non-interactive mode
    if [[ "$1" == "--non-interactive" ]]; then
        shift
        run_non_interactive "$@"
        exit 0
    fi

    check_whiptail
    show_header

    # Welcome message
    local title="$(t "vpn.title")"
    local providers_info="$(t "vpn.providers_info")"

    whiptail --title "$title" \
        --msgbox "$(t "installer.welcome")\n\n$providers_info\n\nVPN routing for privacy protection." 14 70

    # Select provider
    local provider
    provider=$(select_provider)

    if [[ -z "$provider" ]]; then
        echo -e "${YELLOW}$(t "common.cancel")${NC}"
        exit 0
    fi

    # Configure provider-specific settings
    if ! configure_provider "$provider"; then
        echo -e "${RED}$(t "common.error")${NC}"
        exit 1
    fi

    # Save configuration
    save_config "$provider"

    # Create override file
    create_vpn_override "$provider"

    # Show summary
    show_summary "$provider"

    # Optional: Test connection
    if whiptail --title "$(t "vpn.test_connection")" \
        --yesno "$(t "vpn.test_connection") ?\n\n(Docker required)" 10 60; then
        test_vpn_connection
    fi

    echo ""
    echo -e "${GREEN}✅ $(t "common.success") !${NC}"
    echo ""
}

main "$@"
