#!/bin/bash
# MediaHub Password Viewer
# Displays service credentials (requires master password if encrypted)

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  MediaHub - Service Credentials${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check if encrypted credentials exist
if [[ -f "$INSTALL_DIR/.credentials.enc" ]]; then
    echo -e "${YELLOW}Vos mots de passe sont chiffrés pour votre sécurité.${NC}"
    echo ""
    read -sp "Entrez votre mot de passe maître : " master_pass
    echo ""
    echo ""

    # Verify master password by checking hash
    if [[ -f "$INSTALL_DIR/.env" ]]; then
        stored_hash=$(grep "MASTER_PASSWORD_HASH" "$INSTALL_DIR/.env" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$stored_hash" ]]; then
            input_hash=$(echo -n "$master_pass" | sha256sum | cut -d' ' -f1)

            if [[ "$stored_hash" != "$input_hash" ]]; then
                echo -e "${RED}❌ Mot de passe incorrect !${NC}"
                echo ""
                echo "Si vous avez oublié votre mot de passe maître, vous devrez :"
                echo "1. Réinitialiser les mots de passe de chaque service"
                echo "2. Ou réinstaller MediaHub"
                exit 1
            fi
        fi
    fi

    echo -e "${GREEN}✅ Mot de passe vérifié${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Decrypt and display
    openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass pass:"$master_pass" \
        -in "$INSTALL_DIR/.credentials.enc" 2>/dev/null | while IFS='=' read -r key value; do
        case $key in
            JELLYFIN_PASSWORD)
                echo -e "${GREEN}🎬 Jellyfin${NC}"
                echo "   URL: http://localhost:8096"
                echo "   Utilisateur: admin"
                echo "   Mot de passe: $value"
                echo ""
                ;;
            QBITTORRENT_PASSWORD)
                echo -e "${GREEN}⬇️  qBittorrent${NC}"
                echo "   URL: http://localhost:8080"
                echo "   Utilisateur: admin"
                echo "   Mot de passe: $value"
                echo ""
                ;;
            PHOTOPRISM_PASSWORD)
                echo -e "${GREEN}📸 PhotoPrism${NC}"
                echo "   URL: http://localhost:2342"
                echo "   Utilisateur: admin"
                echo "   Mot de passe: $value"
                echo ""
                ;;
            GOTIFY_PASSWORD)
                echo -e "${GREEN}🔔 Gotify${NC}"
                echo "   URL: http://localhost:8070"
                echo "   Utilisateur: admin"
                echo "   Mot de passe: $value"
                echo ""
                ;;
            OPENVPN_USER)
                vpn_user="$value"
                ;;
            OPENVPN_PASS)
                echo -e "${GREEN}🔒 VPN ProtonVPN${NC}"
                echo "   Utilisateur: $vpn_user"
                echo "   Mot de passe: $value"
                echo ""
                ;;
        esac
    done

else
    # No encryption, read from .env directly
    echo -e "${YELLOW}Note: Vos mots de passe ne sont pas chiffrés.${NC}"
    echo "Pour plus de sécurité, utilisez l'installateur wizard."
    echo ""

    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        echo -e "${RED}Fichier .env introuvable !${NC}"
        echo "Chemin attendu: $INSTALL_DIR/.env"
        exit 1
    fi

    source "$INSTALL_DIR/.env"

    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Dashboard
    echo -e "${GREEN}🏠 Dashboard (Homarr)${NC}"
    echo "   URL: http://localhost:7575"
    echo "   Pas d'authentification par défaut"
    echo ""

    # Jellyfin
    if [[ -n "$JELLYFIN_PASSWORD" ]]; then
        echo -e "${GREEN}🎬 Jellyfin${NC}"
        echo "   URL: http://localhost:8096"
        echo "   Utilisateur: ${JELLYFIN_USER:-admin}"
        echo "   Mot de passe: $JELLYFIN_PASSWORD"
        echo ""
    fi

    # qBittorrent
    if [[ -n "$QBITTORRENT_PASSWORD" ]]; then
        echo -e "${GREEN}⬇️  qBittorrent${NC}"
        echo "   URL: http://localhost:8080"
        echo "   Utilisateur: ${QBITTORRENT_USER:-admin}"
        echo "   Mot de passe: $QBITTORRENT_PASSWORD"
        echo ""
    fi

    # Sonarr/Radarr/Prowlarr (API Keys)
    echo -e "${GREEN}📺 Sonarr${NC}"
    echo "   URL: http://localhost:8989"
    echo "   Pas d'authentification par défaut"
    if [[ -n "$SONARR_API_KEY" && "$SONARR_API_KEY" != "your_sonarr_api_key" ]]; then
        echo "   API Key: $SONARR_API_KEY"
    fi
    echo ""

    echo -e "${GREEN}🎥 Radarr${NC}"
    echo "   URL: http://localhost:7878"
    echo "   Pas d'authentification par défaut"
    if [[ -n "$RADARR_API_KEY" && "$RADARR_API_KEY" != "your_radarr_api_key" ]]; then
        echo "   API Key: $RADARR_API_KEY"
    fi
    echo ""

    echo -e "${GREEN}🔍 Prowlarr${NC}"
    echo "   URL: http://localhost:9696"
    echo "   Pas d'authentification par défaut"
    echo ""

    # PhotoPrism
    if [[ -n "$PHOTOPRISM_ADMIN_PASSWORD" && "$PHOTOPRISM_ADMIN_PASSWORD" != "your_secure_password_here" ]]; then
        echo -e "${GREEN}📸 PhotoPrism${NC}"
        echo "   URL: http://localhost:2342"
        echo "   Utilisateur: ${PHOTOPRISM_ADMIN_USER:-admin}"
        echo "   Mot de passe: $PHOTOPRISM_ADMIN_PASSWORD"
        echo ""
    fi

    # Gotify
    if [[ -n "$GOTIFY_PASSWORD" && "$GOTIFY_PASSWORD" != "your_secure_password_here" ]]; then
        echo -e "${GREEN}🔔 Gotify${NC}"
        echo "   URL: http://localhost:8070"
        echo "   Utilisateur: ${GOTIFY_USER:-admin}"
        echo "   Mot de passe: $GOTIFY_PASSWORD"
        echo ""
    fi

    # Pi-hole
    if [[ -n "$PIHOLE_PASSWORD" && "$PIHOLE_PASSWORD" != "your_secure_password_here" ]]; then
        echo -e "${GREEN}🛡️  Pi-hole${NC}"
        echo "   URL: http://localhost:8053/admin"
        echo "   Mot de passe: $PIHOLE_PASSWORD"
        echo ""
    fi

    # VPN
    if [[ -n "$PROTON_USER" && "$PROTON_USER" != "your_openvpn_username" ]]; then
        echo -e "${GREEN}🔒 VPN ProtonVPN${NC}"
        echo "   Utilisateur: $PROTON_USER"
        echo "   Mot de passe: $PROTON_PASS"
        echo ""
    fi
fi

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT :${NC}"
echo "- Gardez ces mots de passe en sécurité"
echo "- Ne les partagez pas"
echo "- Changez les mots de passe par défaut"
echo ""
echo -e "${CYAN}Pour réinitialiser un mot de passe :${NC}"
echo "1. Accédez à l'interface web du service"
echo "2. Allez dans Paramètres > Sécurité"
echo "3. Changez le mot de passe"
echo "4. Mettez à jour le fichier .env si nécessaire"
echo ""
