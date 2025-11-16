#!/bin/bash
# Spanish translations for MediaHub scripts

declare -gA TRANSLATIONS=(
    # Common
    ["common.yes"]="Sí"
    ["common.no"]="No"
    ["common.cancel"]="Cancelar"
    ["common.confirm"]="Confirmar"
    ["common.continue"]="Continuar"
    ["common.back"]="Volver"
    ["common.skip"]="Omitir"
    ["common.error"]="Error"
    ["common.success"]="Éxito"
    ["common.warning"]="Advertencia"

    # Installer
    ["installer.title"]="Instalación de MediaHub"
    ["installer.welcome"]="¡Bienvenido a la instalación de MediaHub!"
    ["installer.welcome_desc"]="Este asistente configurará tu mediacenter completo.\n\nTiempo estimado: 15-30 minutos"

    ["installer.requirements"]="Antes de comenzar"
    ["installer.requirements_desc"]="Asegúrate de tener:\n\n→ Un disco duro externo conectado\n→ Una cuenta VPN (ProtonVPN, NordVPN, Mullvad, etc.)\n→ Tus credenciales VPN OpenVPN/Wireguard\n\n¿Tienes todos estos elementos?"

    ["installer.detecting_hardware"]="Detectando hardware..."
    ["installer.hardware_detected"]="Hardware detectado"
    ["installer.rpi_model"]="Modelo Raspberry Pi"
    ["installer.ram_total"]="RAM total"
    ["installer.hdd_detected"]="Disco duro externo"

    # VPN
    ["vpn.title"]="Configuración VPN"
    ["vpn.select_provider"]="Selecciona tu proveedor VPN"
    ["vpn.providers_info"]="MediaHub soporta 24+ proveedores vía Gluetun"
    ["vpn.username"]="Usuario"
    ["vpn.password"]="Contraseña"
    ["vpn.credentials_warning"]="¡ATENCIÓN: Estas son tus credenciales de SERVICIO, no tu cuenta!"
    ["vpn.credentials_help"]="Estas credenciales son diferentes de tu email/contraseña de cuenta."
    ["vpn.server_country"]="País del servidor"
    ["vpn.server_region"]="Región del servidor"
    ["vpn.username_short"]="El usuario parece demasiado corto."
    ["vpn.password_short"]="La contraseña parece demasiado corta."
    ["vpn.test_connection"]="Probando conexión VPN..."
    ["vpn.test_success"]="¡VPN conectado exitosamente!"
    ["vpn.test_failed"]="Fallo en la conexión VPN"

    # Master Password
    ["password.title"]="Contraseña maestra"
    ["password.desc"]="Esta contraseña protegerá todas tus credenciales.\n\nSe usará para cifrar tus contraseñas.\n\n¡NO LA OLVIDES!"
    ["password.enter"]="Ingresa tu contraseña maestra:"
    ["password.confirm"]="Confirma tu contraseña maestra:"
    ["password.mismatch"]="¡Las contraseñas no coinciden!"
    ["password.weak"]="La contraseña debe tener al menos 8 caracteres."
    ["password.strength"]="Fortaleza de la contraseña"
    ["password.weak_label"]="Débil"
    ["password.medium_label"]="Media"
    ["password.strong_label"]="Fuerte"

    # Features
    ["features.title"]="Funciones opcionales"
    ["features.desc"]="Selecciona las funciones a habilitar:"
    ["features.tv_kiosk"]="Modo TV Kiosk (pantalla completa)"
    ["features.hdmi_cec"]="Control HDMI-CEC (control remoto TV)"
    ["features.notifications"]="Notificaciones (Discord, Telegram, etc.)"
    ["features.monitoring"]="Monitoreo del sistema (temperatura, CPU)"

    # Installation
    ["install.starting"]="Iniciando instalación..."
    ["install.creating_dirs"]="Creando directorios..."
    ["install.pulling_images"]="Descargando imágenes Docker..."
    ["install.configuring"]="Configurando servicios..."
    ["install.starting_services"]="Iniciando servicios..."
    ["install.complete"]="¡Instalación completada!"
    ["install.error"]="Error durante la instalación"
    ["install.rollback"]="Error detectado, revirtiendo..."

    # Notifications
    ["notify.title"]="Configuración de notificaciones"
    ["notify.discord"]="Discord"
    ["notify.telegram"]="Telegram"
    ["notify.gotify"]="Gotify (auto-alojado)"
    ["notify.email"]="Email"
    ["notify.webhook_url"]="URL del webhook"
    ["notify.bot_token"]="Token del bot"
    ["notify.chat_id"]="ID del chat"

    # Services
    ["services.jellyfin"]="Jellyfin - Reproductor multimedia"
    ["services.sonarr"]="Sonarr - Series de TV"
    ["services.radarr"]="Radarr - Películas"
    ["services.prowlarr"]="Prowlarr - Indexadores"
    ["services.qbittorrent"]="qBittorrent - Descargas"

    # Post-install
    ["postinstall.title"]="Configuración post-instalación"
    ["postinstall.api_keys"]="Recuperando claves API..."
    ["postinstall.linking"]="Vinculando servicios..."
    ["postinstall.complete"]="¡Configuración automática completada!"

    # Summary
    ["summary.title"]="Resumen de instalación"
    ["summary.provider"]="Proveedor VPN"
    ["summary.features"]="Funciones habilitadas"
    ["summary.passwords"]="Contraseñas generadas"
    ["summary.ready"]="¡Todo está listo!"
    ["summary.access"]="Accede a tu dashboard"
    ["summary.credentials"]="Ver credenciales"

    # Hardware Mode
    ["hardware.title"]="Modo de instalación"
    ["hardware.description"]="Seleccione su hardware para optimizar la instalación"
    ["hardware.pi4_full"]="Raspberry Pi 4 - Todos los servicios"
    ["hardware.pi3_limited"]="Raspberry Pi 3 - Modo limitado"
    ["hardware.detected"]="Hardware detectado"
    ["hardware.ram"]="RAM"
    ["hardware.mode_full"]="Modo completo"
    ["hardware.mode_limited"]="Modo limitado"
    ["hardware.services_included"]="Servicios incluidos"
    ["hardware.services_excluded"]="Servicios excluidos"
)
