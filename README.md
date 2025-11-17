# MediaHub Unify Tools

Un mediacenter complet et auto-hébergé pour Raspberry Pi 4, basé sur Docker et des projets open-source.

## Fonctionnalités

### Gestion des médias
- **Sonarr** - Gestion automatisée des séries TV
- **Radarr** - Gestion automatisée des films
- **Lidarr** - Gestion automatisée de la musique
- **Readarr** - Gestion des ebooks et audiobooks
- **Mylar3** - Gestion automatisée des comics/manga
- **Bazarr** - Téléchargement automatique des sous-titres
- **Prowlarr** - Gestion centralisée des indexeurs
- **Flaresolverr** - Contournement des protections Cloudflare
- **Recyclarr** - Synchronisation automatique des profils TRaSH Guides

### Téléchargement sécurisé
- **qBittorrent** - Client torrent avec interface web
- **Gluetun** - Container VPN (24+ fournisseurs supportés) pour sécuriser les téléchargements
- **Unpackerr** - Extraction automatique des archives RAR

**Fournisseurs VPN supportés :**
- ProtonVPN, Mullvad, NordVPN, Surfshark, Private Internet Access (PIA)
- ExpressVPN, CyberGhost, IVPN, Windscribe, AirVPN
- Et 14+ autres fournisseurs
- Support OpenVPN et Wireguard
- Configuration personnalisée (vos propres fichiers .ovpn/.conf)

### Serveur multimédia
- **Jellyfin** - Serveur de streaming (alternative libre à Plex)
- **Jellyseerr** - Interface de demandes de contenus
- **Tautulli** - Statistiques de visionnage détaillées
- **Navidrome** - Serveur de streaming musical (alternative à Spotify)
- **Komga** - Serveur de comics/manga avec lecteur web

### Dashboard et gestion

- **Homarr** - Dashboard moderne et personnalisable
- **Heimdall** - Page d'accueil unifiée (alternative)
- **Portainer** - Gestion Docker via interface web

### Monitoring et sécurité

- **Uptime Kuma** - Monitoring de disponibilité des services
- **Netdata** - Surveillance système en temps réel
- **Pi-hole** - Bloqueur de publicités réseau
- **Scrutiny** - Monitoring santé des disques
- **Duplicati** - Sauvegardes automatisées
- **Nginx Proxy Manager** - Reverse proxy

### Automatisation et maintenance

- **Watchtower** - Mises à jour automatiques des containers
- **Notifiarr** - Notifications centralisées (Discord, Telegram, etc.)

### Notifications et alertes

- **Gotify** - Serveur de notifications push auto-hébergé
- **ntfy** - Service pub-sub de notifications léger
- **Mailrise** - Serveur SMTP qui convertit les emails en notifications
- **Apprise API** - API universelle de notifications (70+ services)
- **Alertes système** - Monitoring automatique (VPN, disque, température, services)

### Accès distant

- **Wireguard** - VPN pour accès sécurisé depuis l'extérieur

### Galerie photos

- **Photoprism** - Alternative à Google Photos (reconnaissance faciale, géolocalisation, IA)

## Prérequis

### Matériel

#### Raspberry Pi 4 (Recommandé) - Mode Complet
- **8GB RAM** (recommandé pour tous les services)
- **4GB RAM** (tous les services, performances réduites)
- Carte microSD 32GB+ (Class 10/A2)
- Disque dur externe USB (pour stockage médias)
- Hub USB alimenté (recommandé)
- Système de refroidissement actif
- Câble HDMI vers Google TV

#### Raspberry Pi 3 - Mode Limité ⚠️
- **1GB RAM** - Mode limité uniquement
- Services essentiels (8 au lieu de 37+)
- Pas de transcodage vidéo (lecture directe uniquement)
- Carte microSD 32GB+ (Class 10)
- Swap recommandé : 1GB

**Services inclus en mode limité :**
- ✅ Jellyfin (direct play only)
- ✅ Sonarr, Radarr
- ✅ qBittorrent, Prowlarr
- ✅ Bazarr, Homarr

**Services exclus en mode limité :**
- ❌ PhotoPrism, Komga, Navidrome
- ❌ Grafana, Prometheus, Netdata
- ❌ Lidarr, Readarr, Overseerr
- ❌ Audiobookshelf, FlareSolverr

> **Note :** Le Raspberry Pi 3 est supporté mais déconseillé pour une utilisation intensive. Préférez le Pi 4 avec 4GB+ de RAM.

### Logiciel
- Raspberry Pi OS 64-bit (Bookworm) pour Pi 4
- Raspberry Pi OS 32-bit (Bullseye) pour Pi 3
- Accès internet
- Compte VPN (ProtonVPN, Mullvad, NordVPN, Surfshark, PIA, ou autre fournisseur supporté)

## Installation rapide

### Option 1 : Installation automatique (recommandée)

Installation en une seule commande avec génération automatique des mots de passe sécurisés :

```bash
# 1. Cloner le repository
git clone https://github.com/votre-username/mediahub-unify-tools.git
cd mediahub-unify-tools

# 2. Rendre les scripts exécutables
chmod +x scripts/*.sh

# 3. Lancer l'installation automatique
sudo ./scripts/auto-install.sh
```

L'installateur automatique :

- Détecte automatiquement le matériel (RPi modèle, RAM, HDD)
- Demande uniquement 3 informations essentielles :
  - Votre fournisseur VPN et identifiants (24+ fournisseurs supportés)
  - Un mot de passe maître pour protéger les credentials
  - Confirmation du HDD à utiliser
- Génère des mots de passe sécurisés pour tous les services
- Configure le système, la sécurité, les sauvegardes automatiques
- Active l'affichage TV en mode kiosk
- Démarre tous les services automatiquement
- **Configuration post-installation automatisée** :
  - Récupère et stocke les clés API de tous les services *arr
  - Configure automatiquement qBittorrent dans Sonarr/Radarr
  - Lie Prowlarr à tous les services de téléchargement
  - Intègre FlareSolverr pour le contournement Cloudflare
  - Configure les dossiers racines des bibliothèques
  - Active les alertes système automatiques (toutes les 15 min)
  - Configure Jellyfin (utilisateur admin, bibliothèques, transcodage RPi)

### Option 2 : Installation manuelle

```bash
# 1. Cloner le repository
git clone https://github.com/votre-username/mediahub-unify-tools.git
cd mediahub-unify-tools

# 2. Rendre les scripts exécutables
chmod +x scripts/*.sh

# 3. Lancer l'installation (choisir mode Manuel)
sudo ./scripts/install.sh

# 4. Configurer ProtonVPN
./scripts/setup-protonvpn.sh

# 5. Éditer la configuration
nano /opt/mediahub/.env

# 6. Démarrer les services
/opt/mediahub/start.sh

# 7. Redémarrer pour appliquer toutes les optimisations
sudo reboot
```

## Configuration post-installation

### 1. Accéder aux services
Après le démarrage, accédez aux services via votre navigateur :

| Service | URL | Port |
|---------|-----|------|
| Homarr (Dashboard) | http://IP_RPI:7575 | 7575 |
| Heimdall (Dashboard alt) | http://IP_RPI/ | 80 |
| Jellyfin | http://IP_RPI:8096 | 8096 |
| Tautulli | http://IP_RPI:8181 | 8181 |
| Navidrome | http://IP_RPI:4533 | 4533 |
| Komga | http://IP_RPI:25600 | 25600 |
| Sonarr | http://IP_RPI:8989 | 8989 |
| Radarr | http://IP_RPI:7878 | 7878 |
| Lidarr | http://IP_RPI:8686 | 8686 |
| Mylar3 | http://IP_RPI:8090 | 8090 |
| Prowlarr | http://IP_RPI:9696 | 9696 |
| qBittorrent | http://IP_RPI:8080 | 8080 |
| Jellyseerr | http://IP_RPI:5055 | 5055 |
| Bazarr | http://IP_RPI:6767 | 6767 |
| Code-Server | http://IP_RPI:8444 | 8444 |
| Portainer | http://IP_RPI:9000 | 9000 |
| Uptime Kuma | http://IP_RPI:3001 | 3001 |
| Notifiarr | http://IP_RPI:5454 | 5454 |
| Pi-hole | http://IP_RPI:8053/admin | 8053 |
| Netdata | http://IP_RPI:19999 | 19999 |
| Flaresolverr | http://IP_RPI:8191 | 8191 |
| Photoprism | http://IP_RPI:2342 | 2342 |
| Gotify (Notifications) | http://IP_RPI:8070 | 8070 |
| ntfy (Pub-Sub) | http://IP_RPI:8071 | 8071 |
| Apprise API | http://IP_RPI:8000 | 8000 |
| Mailrise (SMTP) | smtp://IP_RPI:8025 | 8025 |

### 2. Configuration initiale des services

#### Jellyfin
1. Suivre l'assistant de configuration
2. Créer un compte administrateur
3. Ajouter les bibliothèques médias :
   - Films : `/data/movies`
   - Séries : `/data/tvshows`
   - Musique : `/data/music`

#### Prowlarr

1. Ajouter Flaresolverr :
   - Settings > Indexers > Add Indexer Proxy
   - Tag : `flaresolverr`
   - Host : `http://flaresolverr:8191`
2. Ajouter des indexeurs (trackers)
3. Configurer les applications (Sonarr, Radarr, Lidarr)
4. Tester la synchronisation

#### Sonarr/Radarr/Lidarr
1. Ajouter qBittorrent comme client de téléchargement :
   - Host : `gluetun`
   - Port : `8080`
2. Configurer les chemins de médias
3. Définir les profils de qualité

#### qBittorrent
- Login par défaut : `admin` / `adminadmin`
- **Changer le mot de passe immédiatement**

### 3. Configuration HDMI-CEC (télécommande TV)

La télécommande de votre Google TV peut contrôler le Raspberry Pi via HDMI-CEC :

```bash
# Tester la connexion CEC
echo "scan" | cec-client -s -d 1

# Les touches de la télécommande sont automatiquement mappées
# Navigation, lecture/pause, volume fonctionnent directement
```

### 4. Affichage sur TV (Mode Kiosk)

Pour afficher le dashboard MediaHub directement sur votre TV :

```bash
# Installer le mode kiosk
sudo ./scripts/setup-tv-kiosk.sh

# Redémarrer pour activer
sudo reboot
```

Après le redémarrage, Homarr s'affiche en plein écran sur la TV. Commandes utiles :

```bash
# Changer l'application affichée (Jellyfin, Komga, Admin Panel, etc.)
/opt/mediahub/scripts/change-dashboard.sh

# Redémarrer l'affichage
sudo systemctl restart mediahub-kiosk
```

**Interface d'administration TV** (port 8091)

Une interface spécialement conçue pour être utilisée sur grand écran avec télécommande :

- Statut en temps réel de tous les services
- Monitoring système (CPU, RAM, disque, température)
- Actions rapides (redémarrer services, sauvegardes, mises à jour)
- Téléchargements actifs
- Notifications récentes
- Statistiques de la bibliothèque

Contrôles avec la télécommande TV (via HDMI-CEC) :

- **←→** : Navigation entre les panneaux
- **OK** : Sélectionner/Confirmer
- **BACK** : Retour/Annuler
- **R** : Rafraîchir les données

```bash
# Basculer sur l'interface d'administration
/opt/mediahub/scripts/change-dashboard.sh
# Choisir option 5: TV Admin Panel
```

### 5. Configuration des indexeurs (sources de téléchargement)

Prowlarr est déjà connecté à Sonarr/Radarr automatiquement. Il suffit d'ajouter des indexeurs :

```bash
# Configuration automatique des indexeurs populaires
/opt/mediahub/scripts/setup-indexers.sh
```

Trois options disponibles :
1. **Standard Pack** (recommandé) : YTS (films), EZTV (séries TV), 1337x (général)
2. **Full Pack** : Standard + Nyaa.si (anime)
3. **Custom** : Choisissez vos indexeurs

Les indexeurs sont automatiquement synchronisés vers Sonarr et Radarr !

**Configuration manuelle :**

1. Accéder à Prowlarr : http://IP_RPI:9696
2. Aller dans Indexers > Add Indexer
3. Rechercher et ajouter vos sites torrent préférés
4. Les indexeurs seront automatiquement disponibles dans Sonarr/Radarr

**Note** : FlareSolverr est déjà configuré pour contourner les protections Cloudflare.

### 7. Configuration des notifications

MediaHub inclut un système complet de notifications pour vous alerter sur :

- Téléchargements terminés
- Nouveaux épisodes/films disponibles
- Alertes système (VPN down, disque plein, température élevée)
- Sauvegardes complétées
- Mises à jour de conteneurs

```bash
# Configurer les notifications (Discord, Telegram, Gotify, ntfy, Email)
sudo ./scripts/setup-notifications.sh

# Tester les notifications
/opt/mediahub/scripts/test-notifications.sh

# Envoyer une notification manuelle
/opt/mediahub/scripts/notify.sh "Titre" "Message" [priority]
```

**Services de notification disponibles :**

1. **Gotify** (recommandé) - Serveur push auto-hébergé
   - Accès web : http://IP_RPI:8070
   - Applications Android/iOS disponibles
   - Créer une "Application" pour obtenir un token

2. **ntfy** - Service pub-sub simple
   - Accès web : http://IP_RPI:8071/mediahub
   - S'abonner au topic "mediahub"
   - Application mobile disponible

3. **Discord** - Via webhook
   - Créer un webhook dans Server Settings > Integrations
   - Notifications dans un canal dédié

4. **Telegram** - Via bot
   - Créer un bot avec @BotFather
   - Notifications directement dans Telegram

5. **Email** - Via SMTP externe
   - Configuration de votre serveur SMTP (Gmail, etc.)

**Configuration dans les services *arr :**

1. Sonarr/Radarr/Lidarr > Settings > Connect
2. Ajouter "Gotify" ou "Webhook"
3. URL : `http://gotify:80` (interne) ou `http://IP:8070` (externe)
4. Application Token : celui créé dans Gotify

**Alertes système automatiques :**

Le script `system-alerts.sh` surveille automatiquement :

- ✅ Connexion VPN (alerte si déconnecté)
- ✅ Espace disque (alerte à 90%, critique à 95%)
- ✅ Température CPU (alerte à 70°C, critique à 80°C)
- ✅ Services critiques (Jellyfin, Sonarr, etc.)
- ✅ Mémoire RAM (alerte à 90%)
- ✅ Connectivité internet
- ✅ État des sauvegardes

```bash
# Activer les alertes automatiques (toutes les 15 min)
(crontab -l 2>/dev/null; echo "*/15 * * * * /opt/mediahub/scripts/system-alerts.sh") | crontab -
```

## Gestion quotidienne

### Commandes de gestion

```bash
# Démarrer tous les services
/opt/mediahub/start.sh

# Arrêter tous les services
/opt/mediahub/stop.sh

# Mettre à jour les images Docker
/opt/mediahub/update.sh

# Voir le statut des services
/opt/mediahub/status.sh

# Vérifier la santé du système
/opt/mediahub/scripts/health-check.sh
```

### Gestion des mots de passe (installation automatique)

Si vous avez utilisé l'installation automatique, tous les mots de passe sont générés automatiquement et stockés de manière sécurisée (chiffrement AES-256).

```bash
# Voir tous les mots de passe (nécessite le mot de passe maître)
/opt/mediahub/scripts/password-manager.sh show

# Exporter les credentials dans un fichier
/opt/mediahub/scripts/password-manager.sh export /chemin/vers/fichier.txt

# Réinitialiser le mot de passe d'un service spécifique
/opt/mediahub/scripts/password-manager.sh reset qbittorrent

# Changer le mot de passe maître
/opt/mediahub/scripts/password-manager.sh change-master

# Sauvegarder les credentials chiffrés sur le HDD
/opt/mediahub/scripts/password-manager.sh backup
```

**Services avec credentials auto-générés :**

- qBittorrent (admin)
- Jellyfin (admin)
- Pi-hole (admin)
- Photoprism (admin)
- Portainer (admin)
- Nginx Proxy Manager (`admin@example.com`)
- Wireguard
- Notifiarr
- Duplicati

### Sauvegarde et récupération

Le système effectue des **sauvegardes automatiques quotidiennes** à 3h du matin sur le HDD externe.

```bash
# Créer une sauvegarde manuelle
sudo /opt/mediahub/scripts/backup-config.sh

# Voir l'état des sauvegardes
/opt/mediahub/scripts/backup-config.sh --status

# Sauvegarde rapide (sans arrêter les services)
sudo /opt/mediahub/scripts/backup-config.sh --quick
```

**En cas de défaillance de la carte SD :**

```bash
# 1. Flasher une nouvelle carte SD avec Raspberry Pi OS 64-bit
# 2. Brancher le HDD externe
# 3. Exécuter le script de restauration :
sudo /opt/mediahub/scripts/restore-config.sh /mnt/media/backups/mediahub/mediahub_backup_XXXXXXXX_XXXXXX.tar.gz
```

Le script de restauration :

- Installe Docker automatiquement
- Restaure toutes les configurations
- Redémarre tous les services
- Reconfigure les sauvegardes automatiques

**Données sauvegardées :**

- Configurations de tous les services (Sonarr, Radarr, etc.)
- Fichier `.env` avec vos paramètres
- Bases de données des applications
- Profils de qualité et API keys

**Non sauvegardé (déjà sur le HDD) :**

- Films, séries, musique
- Photos et comics
- Téléchargements en cours

### Logs et dépannage

```bash
# Voir les logs d'un service spécifique
docker logs sonarr

# Voir les logs en temps réel
docker logs -f jellyfin

# Voir tous les logs récents
cd /opt/mediahub && docker compose logs --tail=100
```

## Intégration Netflix/Disney+/Amazon

**Important** : Il n'existe pas de solution Docker légale pour intégrer ces services directement.

### Options recommandées :

1. **Utiliser directement la Google TV**
   - Les applications officielles sont disponibles
   - Meilleure qualité et compatibilité

2. **Mode kiosque Chromium**
   - Installer Chromium sur le RPi
   - Lancer en mode kiosk vers les sites de streaming

3. **Kodi avec extensions officielles**
   - Installer Kodi dans Docker ou directement
   - Utiliser les add-ons officiels (nécessite abonnement)

## Sécurité

### VPN (ProtonVPN)
- Tout le trafic torrent passe par le VPN
- Kill switch automatique si le VPN tombe
- Vérifier : `docker exec gluetun wget -qO- https://ipinfo.io`

### Pare-feu
- UFW configuré automatiquement
- Seuls les ports nécessaires sont ouverts

### Fail2ban
- Protection contre les attaques par force brute
- Bannissement automatique après 3 tentatives SSH échouées

### Pi-hole
- Bloque les publicités et trackers au niveau réseau
- Interface admin sur le port 8053

## Optimisation Raspberry Pi

### Performance
- Swap augmenté à 2GB
- GPU memory réduit à 128MB
- Paramètres kernel optimisés
- log2ram pour réduire l'usure de la carte SD

### Stockage
- Configs sur carte SD (rapide)
- Médias sur disque externe USB
- Sauvegardes automatiques

### Température
- Surveiller via Netdata
- Recommandé : < 70°C
- Ajouter un ventilateur si nécessaire

## Structure du projet

```
mediahub-unify-tools/
├── docker-compose.yml          # Configuration principale Docker
├── .env.example                # Template de configuration
├── .gitignore                  # Fichiers à ignorer
├── README.md                   # Documentation
├── config/                     # Configurations des services
│   ├── cec/                   # Configuration télécommande
│   └── iptv/                  # Playlists IPTV
├── scripts/                    # Scripts d'installation et gestion
│   ├── auto-install.sh        # Installation automatique complète
│   ├── install.sh             # Installation (mode auto/manuel)
│   ├── password-manager.sh    # Gestion des mots de passe chiffrés
│   ├── setup-protonvpn.sh     # Configuration VPN
│   ├── setup-tv-kiosk.sh      # Mode kiosk TV
│   ├── backup-config.sh       # Sauvegarde des configurations
│   ├── restore-config.sh      # Restauration après panne SD
│   ├── health-check.sh        # Diagnostic système complet
│   ├── status.sh              # État des services
│   ├── start.sh               # Démarrage des services
│   ├── stop.sh                # Arrêt des services
│   ├── update.sh              # Mise à jour des containers
│   └── format-hdd.sh          # Formatage du HDD externe
└── docs/                       # Documentation supplémentaire
```

## Dépannage

### Le VPN ne se connecte pas
```bash
docker logs gluetun
# Vérifier les credentials dans .env
# S'assurer d'utiliser les credentials OpenVPN, pas le compte ProtonVPN
```

### qBittorrent inaccessible
- Vérifier que Gluetun fonctionne
- Le service dépend du réseau VPN

### Jellyfin lent
- Désactiver le transcodage (lecture directe)
- Vérifier la température du RPi

### Espace disque insuffisant
```bash
# Nettoyer les images Docker inutilisées
docker image prune -a

# Vérifier l'espace
df -h /mnt/media
```

## Mises à jour

```bash
# Mettre à jour tous les containers
cd /opt/mediahub
docker compose pull
docker compose down
docker compose up -d

# Ou utiliser le script
/opt/mediahub/update.sh
```

## Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à :
- Ouvrir des issues pour signaler des bugs
- Proposer des améliorations
- Soumettre des pull requests

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Avertissement

Ce projet est fourni à des fins éducatives. Assurez-vous de respecter les lois locales concernant le téléchargement et le streaming de contenus. L'utilisation d'un VPN ne vous exempte pas de votre responsabilité légale.
