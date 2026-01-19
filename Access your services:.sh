Access your services:
  Dashboard:  http://192.168.1.6:7575
  Jellyfin:   http://192.168.1.6:8096
  Prowlarr:   http://192.168.1.6:9696
  Sonarr:     http://192.168.1.6:8989
  Radarr:     http://192.168.1.6:7878
Your credentials:
=========================================
JELLYFIN_PASSWORD=u40evMdxGQAaUDRh
QBITTORRENT_PASSWORD=pMxaxr6shJ5IFKrR
PHOTOPRISM_PASSWORD=UcaCspzOqxKNYEu4
GOTIFY_PASSWORD=mznKv8Rrpc0JWciL
CODE_SERVER_PASSWORD=H0iZxznqrygRuydj
OPENVPN_USER=
OPENVPN_PASS=

            
git pull origin main


sudo ./scripts/install-wizard.sh
sudo ./scripts/setup-vpn.sh

cd ~ && rm -rf mediahub-unify-tools && git clone https://github.com/Bricol1982/mediahub-unify-tools.git && cd mediahub-unify-tools && chmod +x scripts/*.sh && sudo ./scripts/install-wizard-verbose.sh

cd ~ && rm -rf mediahub-unify-tools && git clone https://github.com/Bricol1982/mediahub-unify-tools.git && cd mediahub-unify-tools && chmod +x scripts/*.sh && sudo ./scripts/install-wizard.sh 