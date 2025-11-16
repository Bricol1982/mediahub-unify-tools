#!/bin/bash
# MediaHub Development Setup
# Creates local dev environment for testing scripts and services

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DATA_DIR="$PROJECT_DIR/dev-data"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  MediaHub Development Setup${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose V2 is not available${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker found${NC}"

# Create dev data directories
echo -e "${CYAN}→ Creating development directories...${NC}"

mkdir -p "$DEV_DATA_DIR"/{config,downloads,library,backups}
mkdir -p "$DEV_DATA_DIR"/config/{jellyfin,sonarr,radarr,prowlarr,qbittorrent,homarr/configs,homarr/data}
mkdir -p "$DEV_DATA_DIR"/library/{movies,tv,music,books,photos}
mkdir -p "$DEV_DATA_DIR"/downloads/{complete,incomplete,torrents}

echo -e "${GREEN}✓ Directories created in ${CYAN}$DEV_DATA_DIR${NC}"

# Copy .env.dev to .env if not exists
if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    echo -e "${CYAN}→ Creating .env from .env.dev...${NC}"
    cp "$PROJECT_DIR/.env.dev" "$PROJECT_DIR/.env"
    echo -e "${GREEN}✓ .env created${NC}"
else
    echo -e "${YELLOW}⚠ .env already exists, keeping current version${NC}"
fi

# Create sample media files for testing
echo -e "${CYAN}→ Creating sample media structure...${NC}"

# Sample movie folders
mkdir -p "$DEV_DATA_DIR/library/movies/Sample Movie (2024)"
echo "This is a sample movie placeholder" > "$DEV_DATA_DIR/library/movies/Sample Movie (2024)/readme.txt"

# Sample TV show folders
mkdir -p "$DEV_DATA_DIR/library/tv/Sample Show/Season 01"
echo "This is a sample TV show placeholder" > "$DEV_DATA_DIR/library/tv/Sample Show/Season 01/readme.txt"

echo -e "${GREEN}✓ Sample media structure created${NC}"

# Create welcome page if not exists
if [[ ! -d "$PROJECT_DIR/docs/welcome" ]]; then
    echo -e "${CYAN}→ Creating welcome page...${NC}"
    mkdir -p "$PROJECT_DIR/docs/welcome"
    cat > "$PROJECT_DIR/docs/welcome/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MediaHub Dev Environment</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            font-size: 3em;
            margin-bottom: 10px;
        }
        .subtitle {
            text-align: center;
            opacity: 0.9;
            margin-bottom: 40px;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
        }
        .service {
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            transition: transform 0.3s;
        }
        .service:hover {
            transform: translateY(-5px);
        }
        .service h3 {
            margin: 0 0 10px 0;
            font-size: 1.3em;
        }
        .service p {
            margin: 0 0 15px 0;
            opacity: 0.9;
            font-size: 0.95em;
        }
        .service a {
            display: inline-block;
            background: rgba(255,255,255,0.25);
            color: white;
            text-decoration: none;
            padding: 8px 16px;
            border-radius: 8px;
            font-weight: 500;
            transition: background 0.3s;
        }
        .service a:hover {
            background: rgba(255,255,255,0.4);
        }
        .warning {
            background: rgba(255,193,7,0.3);
            border-left: 4px solid #ffc107;
            padding: 15px;
            border-radius: 8px;
            margin-top: 30px;
        }
        .warning strong {
            color: #ffc107;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 MediaHub Dev</h1>
        <p class="subtitle">Development Environment - Local Testing</p>

        <div class="services">
            <div class="service">
                <h3>📺 Jellyfin</h3>
                <p>Media streaming server</p>
                <a href="http://localhost:8096" target="_blank">Open :8096</a>
            </div>

            <div class="service">
                <h3>📺 Sonarr</h3>
                <p>TV series management</p>
                <a href="http://localhost:8989" target="_blank">Open :8989</a>
            </div>

            <div class="service">
                <h3>🎬 Radarr</h3>
                <p>Movie management</p>
                <a href="http://localhost:7878" target="_blank">Open :7878</a>
            </div>

            <div class="service">
                <h3>🔍 Prowlarr</h3>
                <p>Indexer manager</p>
                <a href="http://localhost:9696" target="_blank">Open :9696</a>
            </div>

            <div class="service">
                <h3>⬇️ qBittorrent</h3>
                <p>Download client (NO VPN!)</p>
                <a href="http://localhost:8080" target="_blank">Open :8080</a>
            </div>

            <div class="service">
                <h3>🏠 Homarr</h3>
                <p>Dashboard</p>
                <a href="http://localhost:7575" target="_blank">Open :7575</a>
            </div>

            <div class="service">
                <h3>📊 Netdata</h3>
                <p>System monitoring</p>
                <a href="http://localhost:19999" target="_blank">Open :19999</a>
            </div>
        </div>

        <div class="warning">
            <strong>⚠️ DEV ENVIRONMENT</strong><br>
            This is a development setup. <strong>NO VPN protection</strong> is active.<br>
            Do not use for actual downloads. For testing scripts and UI only.
        </div>
    </div>
</body>
</html>
EOF
    echo -e "${GREEN}✓ Welcome page created${NC}"
fi

# Make scripts executable
echo -e "${CYAN}→ Making scripts executable...${NC}"
chmod +x "$PROJECT_DIR/scripts/"*.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✅ Development Environment Ready!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Commands:"
echo -e "  ${YELLOW}Start services:${NC}"
echo -e "    cd $PROJECT_DIR"
echo -e "    docker compose -f docker-compose.dev.yml up -d"
echo ""
echo -e "  ${YELLOW}Stop services:${NC}"
echo -e "    docker compose -f docker-compose.dev.yml down"
echo ""
echo -e "  ${YELLOW}View logs:${NC}"
echo -e "    docker compose -f docker-compose.dev.yml logs -f"
echo ""
echo -e "  ${YELLOW}Check status:${NC}"
echo -e "    docker compose -f docker-compose.dev.yml ps"
echo ""
echo -e "Dev data location: ${CYAN}$DEV_DATA_DIR${NC}"
echo ""
echo -e "Services (after starting):"
echo -e "  Welcome page:  ${CYAN}http://localhost:8888${NC}"
echo -e "  Homarr:        ${CYAN}http://localhost:7575${NC}"
echo -e "  Jellyfin:      ${CYAN}http://localhost:8096${NC}"
echo -e "  Sonarr:        ${CYAN}http://localhost:8989${NC}"
echo -e "  Radarr:        ${CYAN}http://localhost:7878${NC}"
echo -e "  Prowlarr:      ${CYAN}http://localhost:9696${NC}"
echo -e "  qBittorrent:   ${CYAN}http://localhost:8080${NC}"
echo -e "  Netdata:       ${CYAN}http://localhost:19999${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: No VPN protection in dev mode!${NC}"
echo ""
