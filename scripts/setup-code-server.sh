#!/bin/bash
# Setup code-server with recommended extensions for MediaHub development

set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/mediahub}"

echo "Setting up code-server extensions..."

# Wait for code-server to be running
echo "Waiting for code-server to start..."
for i in {1..30}; do
    if docker exec code-server code-server --version &>/dev/null; then
        echo "code-server is running"
        break
    fi
    sleep 2
done

# Install essential extensions
EXTENSIONS=(
    # Docker & Containers
    "ms-azuretools.vscode-docker"

    # YAML/JSON support (for docker-compose, configs)
    "redhat.vscode-yaml"

    # Shell scripting
    "timonwong.shellcheck"
    "foxundermoon.shell-format"

    # Python (for scripts)
    "ms-python.python"

    # Git integration
    "eamodio.gitlens"
    "mhutchie.git-graph"

    # Remote development
    "ms-vscode-remote.remote-containers"

    # Markdown preview
    "yzhang.markdown-all-in-one"

    # Better comments
    "aaron-bond.better-comments"

    # Bracket colorizer
    "CoenraadS.bracket-pair-colorizer-2"

    # Auto rename tag
    "formulahendry.auto-rename-tag"

    # Path intellisense
    "christian-kohler.path-intellisense"

    # HTML/CSS support
    "ecmel.vscode-html-css"
)

echo "Installing ${#EXTENSIONS[@]} extensions..."

for ext in "${EXTENSIONS[@]}"; do
    echo "Installing: $ext"
    docker exec code-server code-server --install-extension "$ext" 2>/dev/null || \
        echo "  Warning: Could not install $ext (may require manual install)"
done

# Create workspace settings
echo "Creating workspace settings..."

mkdir -p "$INSTALL_DIR/config/code-server/data/User"

cat > "$INSTALL_DIR/config/code-server/data/User/settings.json" << 'EOF'
{
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.tabSize": 4,
    "editor.wordWrap": "on",
    "editor.formatOnSave": true,
    "editor.minimap.enabled": false,
    "terminal.integrated.fontSize": 12,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "git.autofetch": true,
    "git.confirmSync": false,
    "docker.showStartPage": false,
    "shellformat.path": "/usr/bin/shfmt",
    "yaml.schemas": {
        "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json": "docker-compose*.yml"
    },
    "files.associations": {
        "*.conf": "properties",
        "*.env": "properties",
        ".env.*": "properties"
    },
    "workbench.startupEditor": "readme",
    "security.workspace.trust.enabled": false
}
EOF

# Create keybindings for TV remote friendly usage
cat > "$INSTALL_DIR/config/code-server/data/User/keybindings.json" << 'EOF'
[
    {
        "key": "f1",
        "command": "workbench.action.showCommands"
    },
    {
        "key": "f2",
        "command": "workbench.action.quickOpen"
    },
    {
        "key": "f3",
        "command": "workbench.action.findInFiles"
    },
    {
        "key": "f5",
        "command": "workbench.action.reloadWindow"
    },
    {
        "key": "ctrl+shift+g",
        "command": "workbench.view.scm"
    }
]
EOF

echo "Creating helpful workspace files..."

# Create a README for the workspace
cat > "$INSTALL_DIR/WORKSPACE_README.md" << 'EOF'
# MediaHub Development Workspace

Welcome to your code-server workspace for MediaHub development!

## Quick Access

- **Docker Compose**: `docker-compose.yml`
- **Scripts**: `scripts/`
- **Configuration**: `config/`
- **Packs**: `config/packs.conf`

## Useful Commands

```bash
# View running containers
docker ps

# View logs
docker compose logs -f [service_name]

# Restart a service
docker compose restart [service_name]

# Switch pack
./scripts/manage-packs.sh switch [minimal|essential|full]

# Check system status
./scripts/health-check.sh
```

## Development Tips

1. Use the integrated terminal (Ctrl+`) for shell commands
2. GitLens extension shows git history inline
3. Docker extension lets you manage containers from sidebar
4. YAML extension validates docker-compose files

## File Structure

```
/workspace (this directory)
├── docker-compose.yml      # Main compose file
├── .env                     # Environment variables
├── scripts/                 # Management scripts
├── config/                  # Service configurations
└── README.md               # Project documentation
```

Happy coding! 🚀
EOF

echo ""
echo "✅ code-server setup complete!"
echo ""
echo "Access code-server at: http://localhost:8443"
echo "Default password: mediahub123 (change in .env: CODE_SERVER_PASSWORD)"
echo ""
echo "Installed extensions:"
for ext in "${EXTENSIONS[@]}"; do
    echo "  - $ext"
done
