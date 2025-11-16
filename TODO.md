Multiligue

je veux dans le menu la possibilité d'un mode Mode light pour raspberry pi3.

Quels OS pour Raspberry pi3 et pi4 sont préférables pour ce projet

# 1. Installer git si nécessaire
sudo apt update && sudo apt install -y git

# 2. Cloner le dépôt
git clone https://github.com/Bricol1982/mediahub-unify-tools.git

# 3. Aller dans le dossier
cd mediahub-unify-tools

# 4. Rendre les scripts exécutables
chmod +x scripts/*.sh

# 5. Lancer l'installation (choisir UNE option)

# Option A - Installation automatique (recommandé)
sudo ./scripts/auto-install.sh

# Option B - Assistant interactif TUI
sudo ./scripts/install-wizard.sh

# Option C - Installation dev rapide (pour tests)
./scripts/dev-install.sh