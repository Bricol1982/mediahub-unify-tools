# Configuration Threadfin + Jellyfin pour la TNT

Ce guide explique comment configurer Threadfin pour intégrer la TV en direct dans Jellyfin.

## Qu'est-ce que Threadfin ?

Threadfin est un proxy M3U qui convertit une playlist IPTV en tuner virtuel HDHomeRun. Jellyfin le reconnaît automatiquement comme source TV en direct.

## Étape 1 : Accéder à Threadfin

1. Démarrer les services :
```bash
/opt/mediahub/start.sh
```

2. Accéder à l'interface web :
```
http://IP_RASPBERRY:34400/web/
```

3. Créer un compte administrateur lors du premier accès

## Étape 2 : Ajouter une playlist M3U

### Sources légales pour la TNT française

Les chaînes de la TNT sont disponibles gratuitement via les plateformes officielles :

**france.tv** (France Télévisions)
- France 2, France 3, France 4, France 5, franceinfo
- URL : https://www.france.tv/

**TF1+** (Groupe TF1)
- TF1, TF1 Séries Films, TFX, LCI
- URL : https://www.tf1.fr/

**6play** (Groupe M6)
- M6, W9, 6ter
- URL : https://www.6play.fr/

**Arte**
- Arte
- URL : https://www.arte.tv/

### Configuration dans Threadfin

1. Aller dans **Playlist** > **Add**
2. Renseigner :
   - Name : `TNT France`
   - Type : `M3U`
   - URL ou File : Chemin vers votre fichier M3U

3. Cliquer sur **Save**

### Créer votre propre M3U

Vous pouvez utiliser le fichier template fourni :
```
/opt/mediahub/config/iptv/tnt-channels.m3u
```

Vous devrez y ajouter les URLs de streaming. Ces URLs peuvent être trouvées via :
- Extensions Kodi (Catch-up TV & More)
- Sites officiels des chaînes
- Outils comme youtube-dl/yt-dlp pour extraire les flux

**Exemple de ligne M3U complète :**
```
#EXTINF:-1 tvg-id="France2.fr" tvg-name="France 2" group-title="TNT",France 2
https://exemple-flux-france2.m3u8
```

## Étape 3 : Configurer l'EPG (Guide des programmes)

L'EPG (Electronic Program Guide) affiche le programme TV.

1. Dans Threadfin, aller dans **XMLTV** > **Add**
2. Sources EPG gratuites pour la France :
   - `http://www.xmltvfr.fr/xml/xmltv.xml`
   - `https://xmltv.ch/xmltv/xmltv-tnt.xml`

3. Cliquer sur **Save**
4. Aller dans **Mapping** pour associer les chaînes à l'EPG

## Étape 4 : Intégrer à Jellyfin

### Ajouter Threadfin comme tuner

1. Dans Jellyfin, aller dans **Dashboard** > **Live TV**
2. Cliquer sur **Add Tuner Device**
3. Type : **HD Homerun**
4. URL du tuner :
```
http://threadfin:34400
```
(ou `http://IP_RASPBERRY:34400` si accès externe)

5. Cliquer sur **Save**

### Ajouter le guide des programmes

1. Toujours dans **Live TV**, section **TV Guide Data Providers**
2. Cliquer sur **Add**
3. Type : **XMLTV**
4. URL :
```
http://threadfin:34400/xmltv/threadfin.xml
```

5. Cliquer sur **Save**

### Rafraîchir les données

1. Aller dans **Dashboard** > **Scheduled Tasks**
2. Exécuter **Refresh Guide**
3. Attendre quelques minutes

## Étape 5 : Regarder la TV

1. Dans l'interface Jellyfin (web ou app)
2. Aller dans **Live TV** ou **TV en direct**
3. Vos chaînes TNT apparaissent !

### Fonctionnalités disponibles

- **Live TV** : Regarder en direct
- **Guide** : Programme TV avec horaires
- **Recordings** : Enregistrer des émissions (si activé)
- **Series Recordings** : Enregistrer une série entière

## Dépannage

### Les chaînes n'apparaissent pas

1. Vérifier que Threadfin est démarré :
```bash
docker logs threadfin
```

2. Tester l'accès au tuner :
```bash
curl http://localhost:34400/discover.json
```

3. Vérifier le mapping dans Threadfin :
   - Toutes les chaînes doivent être "Active"

### Pas d'EPG / Guide vide

1. Vérifier la source XMLTV dans Threadfin
2. S'assurer que le mapping chaîne ↔ EPG est correct
3. Relancer le refresh dans Jellyfin

### Buffering / Qualité mauvaise

1. Vérifier votre connexion internet
2. Réduire la qualité du flux si disponible
3. Le RPi4 peut avoir du mal avec les flux 1080p

### "Tuner not found"

Vérifier l'URL dans Jellyfin :
- Depuis Jellyfin container : `http://threadfin:34400`
- Depuis l'extérieur : `http://IP_RPI:34400`

## Configuration avancée

### Filtrer les chaînes

Dans Threadfin > **Filter** :
- Désactiver les chaînes non désirées
- Regrouper par catégorie
- Réorganiser l'ordre

### Plusieurs playlists

Vous pouvez ajouter plusieurs sources M3U :
- TNT France
- Chaînes internationales
- Flux personnalisés

### Buffer et cache

Dans Threadfin > **Settings** :
- Buffer : Augmenter pour connexions instables
- Cache : Réduire l'utilisation mémoire

## Alternative : Catch-up TV & More

Si vous préférez les replays et une configuration automatique :

1. Installer Kodi sur le RPi (en parallèle de Jellyfin)
2. Ajouter l'extension "Catch-up TV & More"
3. Configuration automatique de toutes les chaînes françaises

Cette méthode est complémentaire à Threadfin et offre :
- Replays (programmes passés)
- Direct
- Émissions à la demande

## Ressources

- [Documentation Threadfin](https://github.com/Threadfin/Threadfin)
- [Wiki Jellyfin Live TV](https://jellyfin.org/docs/general/server/live-tv/)
- [XMLTV France](http://xmltv.ch/)
- [Catch-up TV & More](https://catch-up-tv-and-more.github.io/)
