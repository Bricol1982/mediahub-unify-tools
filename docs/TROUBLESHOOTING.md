# Guide de Dépannage

## Problèmes courants et solutions

---

## VPN / Gluetun

### Le VPN ne se connecte pas

**Symptômes :**
- Gluetun redémarre en boucle
- qBittorrent inaccessible

**Solutions :**

1. Vérifier les credentials :
```bash
# S'assurer d'utiliser les credentials OpenVPN
# PAS les identifiants de compte ProtonVPN
cat /opt/mediahub/.env | grep PROTON
```

2. Vérifier les logs :
```bash
docker logs gluetun --tail=50
```

3. Erreurs courantes :
   - "AUTH_FAILED" → Mauvais credentials
   - "TLS handshake failed" → Problème réseau/FAI
   - "Cannot connect" → Pays non disponible dans votre plan

4. Tester avec un autre pays :
```bash
# Dans .env, changer :
VPN_COUNTRY=Switzerland
# Puis redémarrer :
docker compose restart gluetun
```

### Fuite IP (VPN actif mais IP locale visible)

```bash
# Vérifier l'IP sortante
docker exec gluetun wget -qO- https://ipinfo.io

# Si c'est votre IP locale, vérifier le kill switch
docker exec gluetun cat /gluetun/ip
```

---

## qBittorrent

### Impossible d'accéder à l'interface web

**Vérifications :**

1. Gluetun fonctionne-t-il ?
```bash
docker ps | grep gluetun
# Doit être "Up"
```

2. qBittorrent est-il démarré ?
```bash
docker logs qbittorrent --tail=20
```

3. Port correct ?
- L'interface est sur le port 8080
- Via le réseau de Gluetun

### Téléchargements très lents

1. Vérifier la connexion VPN
2. Augmenter les connexions :
   - Settings > Connection
   - Global maximum connections: 500
   - Maximum connections per torrent: 100

3. Vérifier les ports :
```bash
# Port forwarding activé dans Gluetun ?
docker exec gluetun cat /tmp/gluetun/forwarded_port
```

### Erreur "Stalled"

- Pas assez de seeders
- Tracker bloqué
- VPN bloque les connexions

---

## Sonarr / Radarr / Lidarr

### Cannot connect to download client

**Configuration correcte :**
- Host: `gluetun` (pas localhost ni l'IP)
- Port: `8080`
- Use SSL: Non

### Imports échouent

1. Vérifier les permissions :
```bash
ls -la /mnt/media/downloads/
ls -la /mnt/media/library/
# Doit appartenir à votre utilisateur (PUID/PGID)
```

2. Corriger si nécessaire :
```bash
sudo chown -R 1000:1000 /mnt/media/
```

3. Vérifier les chemins dans le container :
```bash
docker exec sonarr ls -la /downloads/
docker exec sonarr ls -la /tv/
```

### Indexers not syncing from Prowlarr

1. Dans Prowlarr, vérifier la connexion :
   - Settings > Apps
   - Test la connexion Sonarr/Radarr

2. API Key correcte ?
   - Sonarr : Settings > General > API Key
   - Reporter cette clé dans Prowlarr

### Media not found after download

Problème de mapping des chemins. Vérifier que :
- qBittorrent sauvegarde dans `/downloads`
- Sonarr/Radarr peuvent lire `/downloads`
- Les deux utilisent le même chemin réel

---

## Jellyfin

### Buffering constant

1. Désactiver le transcodage :
   - Playback Settings > Transcoding
   - Disable all transcoding

2. Utiliser la lecture directe :
   - Client Settings > Quality > Maximum

3. Vérifier le réseau :
```bash
# Test débit local
iperf3 -c IP_RPI
```

### Métadonnées manquantes

1. Vérifier la structure des dossiers :
```
/movies/
  Nom du Film (2024)/
    Nom du Film (2024).mkv
```

2. Scanner manuellement :
   - Dashboard > Libraries > Scan

3. Identifier manuellement :
   - Clic droit sur le média > Identify

### Hardware acceleration ne fonctionne pas

Sur RPi4 :
```bash
# Vérifier les devices
ls -la /dev/video*
# Doit montrer video10, video11, video12

# Vérifier que Jellyfin y a accès
docker exec jellyfin ls -la /dev/video*
```

---

## Raspberry Pi

### Température trop élevée (>70°C)

1. Vérifier la température :
```bash
vcgencmd measure_temp
```

2. Solutions :
   - Ajouter un ventilateur
   - Améliorer la circulation d'air
   - Réduire les services actifs

3. Undervoltage warning :
```bash
# Vérifier les logs
dmesg | grep -i voltage
```
   - Utiliser l'alimentation officielle 15W
   - Éviter les câbles USB de mauvaise qualité

### Carte SD corrompue

**Prévention :**
- log2ram installé automatiquement
- Sauvegardes régulières

**Récupération :**
```bash
# Depuis un autre PC
sudo fsck /dev/mmcblk0p2
```

### Out of Memory (OOM)

1. Vérifier la mémoire :
```bash
free -h
```

2. Augmenter le swap :
```bash
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=4096
sudo systemctl restart dphys-swapfile
```

3. Réduire les services :
```bash
# Arrêter les services non essentiels
docker compose stop netdata scrutiny
```

---

## Docker

### Containers qui redémarrent en boucle

```bash
# Identifier le problème
docker logs CONTAINER_NAME --tail=100

# Causes fréquentes :
# - Permissions incorrectes
# - Fichiers de config corrompus
# - Manque de mémoire
```

### Plus d'espace disque

1. Nettoyer Docker :
```bash
docker system prune -a
docker volume prune
```

2. Vérifier les logs :
```bash
sudo du -sh /var/lib/docker/containers/*
# Tronquer les gros fichiers de log
```

### Impossible de pull les images

```bash
# Vérifier la connexion
ping hub.docker.com

# Si problème DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

---

## Réseau

### Services inaccessibles depuis le réseau local

1. Vérifier le pare-feu :
```bash
sudo ufw status
```

2. Ajouter les ports manquants :
```bash
sudo ufw allow 8096/tcp  # Jellyfin
```

3. Vérifier que les services écoutent :
```bash
sudo netstat -tlnp | grep LISTEN
```

### Pi-hole bloque les services

1. Accéder à Pi-hole admin
2. Query Log > voir ce qui est bloqué
3. Whitelist les domaines nécessaires

### Conflits de ports

```bash
# Voir les ports utilisés
sudo netstat -tlnp

# Si conflit, modifier dans docker-compose.yml
ports:
  - "8097:8096"  # Changer le port externe
```

---

## Logs utiles

### Commandes de diagnostic

```bash
# Tous les logs Docker
docker compose logs --tail=100

# Logs d'un service spécifique
docker logs sonarr --tail=50

# Logs système
journalctl -u docker.service

# Logs kernel (hardware)
dmesg | tail -50

# Espace disque
df -h
du -sh /mnt/media/*
```

### Fichiers de configuration à vérifier

```bash
# Configuration principale
cat /opt/mediahub/.env

# Docker compose
cat /opt/mediahub/docker-compose.yml

# Système
cat /boot/config.txt
cat /etc/fstab
```

---

## Support

Si le problème persiste :

1. Collecter les informations :
```bash
/opt/mediahub/scripts/health-check.sh > health_report.txt
docker compose logs > docker_logs.txt
```

2. Vérifier la documentation officielle de chaque service

3. Consulter les communautés :
   - Reddit: r/selfhosted, r/radarr, r/sonarr
   - GitHub issues des projets concernés
   - Forums Jellyfin/Plex
