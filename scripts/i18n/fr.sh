#!/bin/bash
# French translations for MediaHub scripts

declare -gA TRANSLATIONS=(
    # Common
    ["common.yes"]="Oui"
    ["common.no"]="Non"
    ["common.cancel"]="Annuler"
    ["common.confirm"]="Confirmer"
    ["common.continue"]="Continuer"
    ["common.back"]="Retour"
    ["common.skip"]="Passer"
    ["common.error"]="Erreur"
    ["common.success"]="Succès"
    ["common.warning"]="Attention"

    # Installer
    ["installer.title"]="Installation MediaHub"
    ["installer.welcome"]="Bienvenue dans l'installation MediaHub !"
    ["installer.welcome_desc"]="Cet assistant va configurer votre mediacenter complet.\n\nDurée estimée : 15-30 minutes"

    ["installer.requirements"]="Avant de commencer"
    ["installer.requirements_desc"]="Assurez-vous d'avoir :\n\n→ Un disque dur externe branché\n→ Un compte VPN (ProtonVPN, NordVPN, Mullvad, etc.)\n→ Vos identifiants VPN OpenVPN/Wireguard\n\nAvez-vous tous ces éléments ?"

    ["installer.detecting_hardware"]="Détection du matériel en cours..."
    ["installer.hardware_detected"]="Matériel détecté"
    ["installer.rpi_model"]="Modèle Raspberry Pi"
    ["installer.ram_total"]="RAM totale"
    ["installer.hdd_detected"]="Disque dur externe"

    # VPN
    ["vpn.title"]="Configuration VPN"
    ["vpn.select_provider"]="Sélectionnez votre fournisseur VPN"
    ["vpn.providers_info"]="MediaHub supporte 24+ fournisseurs via Gluetun"
    ["vpn.username"]="Nom d'utilisateur"
    ["vpn.password"]="Mot de passe"
    ["vpn.credentials_warning"]="ATTENTION : Ce sont vos identifiants de SERVICE, pas votre compte !"
    ["vpn.credentials_help"]="Ces identifiants sont différents de votre email/mot de passe de compte."
    ["vpn.server_country"]="Pays du serveur"
    ["vpn.server_region"]="Région du serveur"
    ["vpn.username_short"]="Le nom d'utilisateur semble trop court."
    ["vpn.password_short"]="Le mot de passe semble trop court."
    ["vpn.test_connection"]="Test de connexion VPN en cours..."
    ["vpn.test_success"]="VPN connecté avec succès !"
    ["vpn.test_failed"]="Échec de la connexion VPN"

    # Master Password
    ["password.title"]="Mot de passe maître"
    ["password.desc"]="Ce mot de passe protégera tous vos identifiants.\n\nIl sera utilisé pour chiffrer vos mots de passe.\n\nNE L'OUBLIEZ PAS !"
    ["password.enter"]="Entrez votre mot de passe maître :"
    ["password.confirm"]="Confirmez votre mot de passe maître :"
    ["password.mismatch"]="Les mots de passe ne correspondent pas !"
    ["password.weak"]="Le mot de passe doit faire au moins 8 caractères."
    ["password.strength"]="Force du mot de passe"
    ["password.weak_label"]="Faible"
    ["password.medium_label"]="Moyen"
    ["password.strong_label"]="Fort"

    # Features
    ["features.title"]="Fonctionnalités optionnelles"
    ["features.desc"]="Sélectionnez les fonctionnalités à activer :"
    ["features.tv_kiosk"]="Mode TV Kiosk (affichage plein écran)"
    ["features.hdmi_cec"]="Contrôle HDMI-CEC (télécommande TV)"
    ["features.notifications"]="Notifications (Discord, Telegram, etc.)"
    ["features.monitoring"]="Monitoring système (température, CPU)"

    # Installation
    ["install.starting"]="Démarrage de l'installation..."
    ["install.creating_dirs"]="Création des répertoires..."
    ["install.pulling_images"]="Téléchargement des images Docker..."
    ["install.configuring"]="Configuration des services..."
    ["install.starting_services"]="Démarrage des services..."
    ["install.complete"]="Installation terminée !"
    ["install.error"]="Erreur pendant l'installation"
    ["install.rollback"]="Erreur détectée, rollback en cours..."

    # Notifications
    ["notify.title"]="Configuration des notifications"
    ["notify.discord"]="Discord"
    ["notify.telegram"]="Telegram"
    ["notify.gotify"]="Gotify (auto-hébergé)"
    ["notify.email"]="Email"
    ["notify.webhook_url"]="URL du webhook"
    ["notify.bot_token"]="Token du bot"
    ["notify.chat_id"]="ID du chat"

    # Services
    ["services.jellyfin"]="Jellyfin - Lecteur multimédia"
    ["services.sonarr"]="Sonarr - Séries TV"
    ["services.radarr"]="Radarr - Films"
    ["services.prowlarr"]="Prowlarr - Indexeurs"
    ["services.qbittorrent"]="qBittorrent - Téléchargements"

    # Post-install
    ["postinstall.title"]="Configuration post-installation"
    ["postinstall.api_keys"]="Récupération des clés API..."
    ["postinstall.linking"]="Liaison des services..."
    ["postinstall.complete"]="Configuration automatique terminée !"

    # Summary
    ["summary.title"]="Résumé de l'installation"
    ["summary.provider"]="Fournisseur VPN"
    ["summary.features"]="Fonctionnalités activées"
    ["summary.passwords"]="Mots de passe générés"
    ["summary.ready"]="Tout est prêt !"
    ["summary.access"]="Accédez à votre dashboard"
    ["summary.credentials"]="Voir les identifiants"

    # Hardware Mode
    ["hardware.title"]="Mode d'installation"
    ["hardware.description"]="Sélectionnez votre matériel pour optimiser l'installation"
    ["hardware.pi4_full"]="Raspberry Pi 4 - Tous les services"
    ["hardware.pi3_limited"]="Raspberry Pi 3 - Mode limité"
    ["hardware.detected"]="Matériel détecté"
    ["hardware.ram"]="RAM"
    ["hardware.mode_full"]="Mode complet"
    ["hardware.mode_limited"]="Mode limité"
    ["hardware.services_included"]="Services inclus"
    ["hardware.services_excluded"]="Services exclus"
)
