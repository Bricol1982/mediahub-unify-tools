# Guide de Configuration Détaillé

## Table des matières
1. [Configuration initiale](#configuration-initiale)
2. [ProtonVPN](#protonvpn)
3. [Sonarr](#sonarr)
4. [Radarr](#radarr)
5. [Jellyfin](#jellyfin)
6. [IPTV TNT](#iptv-tnt)
7. [Optimisations avancées](#optimisations-avancées)

---

## Configuration initiale

### Fichier .env

Le fichier `.env` contient toutes les variables de configuration. Voici les plus importantes :

```bash
# Identifiants utilisateur (obtenir avec: id $USER)
PUID=1000
PGID=1000

# Fuseau horaire
TZ=Europe/Paris

# Chemins - ADAPTER À VOTRE CONFIGURATION
CONFIG_PATH=/opt/mediahub/config      # Configs (sur carte SD)
DOWNLOAD_PATH=/mnt/media/downloads     # Téléchargements (HDD)
MEDIA_PATH=/mnt/media/library          # Bibliothèque (HDD)
```

### Montage du disque dur externe

1. Identifier le disque :
```bash
lsblk
# Repérer votre disque (ex: /dev/sda1)
```

2. Obtenir l'UUID :
```bash
sudo blkid /dev/sda1
```

3. Ajouter au fstab :
```bash
sudo nano /etc/fstab
# Ajouter :
UUID=votre-uuid /mnt/media ext4 defaults,nofail 0 2
```

4. Monter :
```bash
sudo mount -a
```

---

## ProtonVPN

### Obtenir les credentials

1. Se connecter sur https://account.protonvpn.com
2. Aller dans Account > OpenVPN/IKEv2 username
3. Copier le username et password (PAS vos identifiants de compte)

### Configuration Gluetun

Dans `.env` :
```bash
PROTON_USER=votre_openvpn_username
PROTON_PASS=votre_openvpn_password
VPN_COUNTRY=Netherlands
```

### Vérifier le fonctionnement

```bash
# Démarrer uniquement Gluetun
docker compose up -d gluetun

# Vérifier les logs
docker logs gluetun

# Tester l'IP externe
docker exec gluetun wget -qO- https://ipinfo.io
```

### Pays recommandés pour torrenting
- Netherlands (meilleur)
- Switzerland
- Sweden
- Iceland

---

## Sonarr

### Configuration du client de téléchargement

1. Aller dans Settings > Download Clients
2. Ajouter qBittorrent :
   - Name: qBittorrent
   - Host: `gluetun` (pas localhost!)
   - Port: `8080`
   - Username: admin
   - Password: (celui configuré dans qBittorrent)
   - Category: sonarr
   - Remove Completed: Yes

### Configuration des chemins

1. Settings > Media Management
2. Root Folders :
   - Add Root Folder: `/tv`

### Profils de qualité recommandés

1. Settings > Profiles
2. Créer un profil "HD-1080p" :
   - HDTV-1080p
   - WEBDL-1080p
   - WEBRip-1080p
   - Bluray-1080p

### Indexeurs

Les indexeurs sont gérés via Prowlarr. Dans Prowlarr :
1. Settings > Apps
2. Add Application > Sonarr
3. Renseigner l'API Key de Sonarr

---

## Radarr

Configuration similaire à Sonarr :

### Client de téléchargement
- Host: `gluetun`
- Port: `8080`
- Category: radarr

### Chemins
- Root Folder: `/movies`

### Profils de qualité
Pour films :
- Bluray-1080p
- WEBDL-1080p
- Remux-1080p (si espace suffisant)

---

## Jellyfin

### Configuration initiale

1. Accéder à http://IP:8096
2. Créer un compte administrateur
3. Langue : Français (France)

### Bibliothèques

Ajouter les bibliothèques :

**Films :**
- Dossier : `/data/movies`
- Type : Films
- Langue : Français
- Télécharger les métadonnées : Activé

**Séries :**
- Dossier : `/data/series`
- Type : Séries
- Langue : Français
- Télécharger les métadonnées : Activé

**Musique :**
- Dossier : `/data/music`
- Type : Musique

### Hardware transcoding (RPi4)

1. Dashboard > Settings > Playback
2. Transcoding :
   - Enable hardware acceleration: Video4Linux2 (V4L2)
   - Hardware encoding: Activer

**Note :** Le transcodage sur RPi4 est limité. Privilégier la lecture directe.

### Accès distant

Pour accéder depuis l'extérieur :
1. Configurer un port forwarding sur votre routeur
2. Utiliser Nginx Proxy Manager pour HTTPS
3. Ou utiliser un service comme Tailscale

---

## IPTV TNT

### Configuration Threadfin

1. Accéder à http://IP:34400/web
2. Settings > Files
   - Ajouter votre playlist M3U
   - Configurer l'EPG XMLTV

3. Dans Jellyfin :
   - Dashboard > Live TV > Add Tuner Device
   - Type: HDHomeRun
   - URL: http://threadfin:34400

### Sources légales pour flux TNT

Les chaînes gratuites de la TNT proposent souvent des flux officiels :
- france.tv (France 2, 3, 4, 5, franceinfo)
- TF1+ (TF1, TF1 Séries Films, TFX, LCI)
- 6play (M6, W9, 6ter)
- Arte.tv (Arte)

Vous devrez trouver les URLs de flux vous-même car elles changent régulièrement.

### EPG (Guide des programmes)

1. Configuration > Channel/EPG > EPG Grabber Modules
2. Activer un module EPG (ex: tv_grab_fr)
3. Configurer la mise à jour automatique

---

## Optimisations avancées

### Réduire l'utilisation CPU

```yaml
# Dans docker-compose.yml, ajouter des limites :
services:
  sonarr:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Désactiver les services non utilisés

Si vous n'utilisez pas certains services :
```bash
# Dans docker-compose.yml, commenter les services inutiles
# Ou les exclure au démarrage :
docker compose up -d --scale readarr=0 --scale lidarr=0
```

### Automatiser les mises à jour

Créer un cron job :
```bash
crontab -e
# Ajouter (mise à jour hebdomadaire le dimanche à 4h) :
0 4 * * 0 /opt/mediahub/update.sh >> /opt/mediahub/logs/update.log 2>&1
```

### Monitoring des téléchargements

Configurer des notifications dans Sonarr/Radarr :
1. Settings > Connect
2. Add Connection
3. Options : Discord, Telegram, Email, etc.

### Nettoyage automatique

Script pour nettoyer les fichiers orphelins :
```bash
#!/bin/bash
# Nettoyer les téléchargements de plus de 7 jours
find /mnt/media/downloads/complete -mtime +7 -delete
```

---

## Conseils de sécurité

### Changer tous les mots de passe par défaut

- qBittorrent : admin/adminadmin → À CHANGER
- Tous les services *arr : Créer des mots de passe forts
- Pi-hole : Définir dans .env

### Sauvegardes régulières

```bash
# Programmer une sauvegarde hebdomadaire
0 3 * * 0 /opt/mediahub/scripts/backup.sh
```

### Surveiller les logs

```bash
# Créer un alias utile
alias mediahub-logs='cd /opt/mediahub && docker compose logs -f --tail=50'
```

### Mettre à jour régulièrement

- Images Docker : Hebdomadaire
- Système Raspberry Pi : Mensuel
- Renouveler les credentials VPN si nécessaire
