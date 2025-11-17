#!/usr/bin/env python3
"""
MediaHub TV Admin API Server
Provides REST API for TV-based administration interface
"""

import json
import subprocess
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

PORT = 8090
INSTALL_DIR = os.environ.get('INSTALL_DIR', '/opt/mediahub')

class MediaHubAPIHandler(SimpleHTTPRequestHandler):
    """Custom HTTP handler with API endpoints"""

    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/api/status':
            self.send_json(self.get_system_status())
        elif self.path == '/api/packs':
            self.send_json(self.get_packs_info())
        elif self.path == '/health':
            self.send_health_page()
        elif self.path.startswith('/api/'):
            self.send_error(404, 'API endpoint not found')
        else:
            # Serve static files
            super().do_GET()

    def do_POST(self):
        """Handle POST requests"""
        if self.path == '/api/action/restart':
            result = self.restart_services()
            self.send_json({'success': result})
        elif self.path == '/api/action/update':
            result = self.update_containers()
            self.send_json({'success': result})
        elif self.path == '/api/action/backup':
            result = self.create_backup()
            self.send_json({'success': result})
        elif self.path == '/api/action/reboot':
            result = self.reboot_system()
            self.send_json({'success': result})
        elif self.path.startswith('/api/service/'):
            parts = self.path.split('/')
            if len(parts) >= 5:
                container = parts[3]
                action = parts[4]
                result = self.manage_service(container, action)
                self.send_json({'success': result})
            else:
                self.send_error(400, 'Invalid service action')
        elif self.path == '/api/notify':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')
            data = json.loads(body)
            result = self.send_notification(data.get('title', ''), data.get('message', ''))
            self.send_json({'success': result})
        elif self.path == '/api/action/switch-pack':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')
            data = json.loads(body)
            result = self.switch_pack(data.get('pack', 'essential'))
            self.send_json({'success': result})
        else:
            self.send_error(404, 'API endpoint not found')

    def send_json(self, data):
        """Send JSON response"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def send_health_page(self):
        """Redirect to health check output"""
        self.send_response(302)
        self.send_header('Location', '/health.html')
        self.end_headers()

    def get_system_status(self):
        """Gather system status information"""
        status = {
            'vpn': self.get_vpn_status(),
            'internet': self.check_internet(),
            'cpu_temp': self.get_cpu_temp(),
            'memory': self.get_memory_usage(),
            'disk': self.get_disk_usage('/mnt/media'),
            'sd': self.get_disk_usage('/'),
            'services': self.get_services_status(),
            'downloads': self.get_active_downloads(),
            'notifications': self.get_recent_notifications(),
            'library': self.get_library_stats()
        }
        return status

    def get_vpn_status(self):
        """Check VPN connection status"""
        try:
            result = subprocess.run(
                ['docker', 'exec', 'gluetun', 'wget', '-qO-', 'https://ipinfo.io'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                info = json.loads(result.stdout)
                return {
                    'connected': True,
                    'ip': info.get('ip', 'Unknown'),
                    'country': info.get('country', 'Unknown')
                }
        except Exception:
            pass
        return {'connected': False, 'ip': '', 'country': ''}

    def check_internet(self):
        """Check internet connectivity"""
        try:
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '2', '8.8.8.8'],
                capture_output=True, timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False

    def get_cpu_temp(self):
        """Get CPU temperature (Raspberry Pi)"""
        try:
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = int(f.read().strip()) // 1000
                return temp
        except Exception:
            return 0

    def get_memory_usage(self):
        """Get memory usage percentage"""
        try:
            with open('/proc/meminfo', 'r') as f:
                lines = f.readlines()
                total = int(lines[0].split()[1])
                available = int(lines[2].split()[1])
                used_percent = int(((total - available) / total) * 100)
                return {'used': used_percent, 'total': total // 1024 // 1024}
        except Exception:
            return {'used': 0, 'total': 0}

    def get_disk_usage(self, path):
        """Get disk usage for a given path"""
        try:
            result = subprocess.run(
                ['df', path],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        used_percent = int(parts[4].replace('%', ''))
                        total_gb = int(parts[1]) // 1024 // 1024
                        return {'used': used_percent, 'total': total_gb}
        except Exception:
            pass
        return {'used': 0, 'total': 0}

    def get_services_status(self):
        """Get status of all MediaHub services"""
        services = [
            {'name': 'Jellyfin', 'container': 'jellyfin'},
            {'name': 'Sonarr', 'container': 'sonarr'},
            {'name': 'Radarr', 'container': 'radarr'},
            {'name': 'qBittorrent', 'container': 'qbittorrent'},
            {'name': 'Prowlarr', 'container': 'prowlarr'},
            {'name': 'Gluetun (VPN)', 'container': 'gluetun'},
            {'name': 'Navidrome', 'container': 'navidrome'},
            {'name': 'Komga', 'container': 'komga'},
            {'name': 'Lidarr', 'container': 'lidarr'},
            {'name': 'Gotify', 'container': 'gotify'},
        ]

        for service in services:
            try:
                result = subprocess.run(
                    ['docker', 'inspect', service['container'], '--format', '{{.State.Status}}'],
                    capture_output=True, text=True, timeout=5
                )
                service['status'] = result.stdout.strip() if result.returncode == 0 else 'stopped'
            except Exception:
                service['status'] = 'unknown'

        return services

    def get_active_downloads(self):
        """Get active downloads from qBittorrent"""
        # This would require qBittorrent API integration
        # For now, return empty list
        return []

    def get_recent_notifications(self):
        """Get recent system notifications"""
        notifications = []
        log_file = f'{INSTALL_DIR}/logs/notifications.log'

        try:
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    lines = f.readlines()[-10:]
                    for line in reversed(lines):
                        parts = line.strip().split('|')
                        if len(parts) >= 3:
                            notifications.append({
                                'type': parts[0],
                                'message': parts[1],
                                'time': parts[2]
                            })
        except Exception:
            pass

        # Add some default notifications if none
        if not notifications:
            notifications = [
                {'type': 'info', 'message': 'Système opérationnel', 'time': 'Maintenant'}
            ]

        return notifications

    def get_library_stats(self):
        """Get media library statistics"""
        stats = {'movies': 0, 'tv': 0, 'music': 0, 'comics': 0}

        paths = {
            'movies': '/mnt/media/library/movies',
            'tv': '/mnt/media/library/tv',
            'music': '/mnt/media/library/music',
            'comics': '/mnt/media/library/comics'
        }

        for key, path in paths.items():
            try:
                if os.path.exists(path):
                    # Count directories (each represents a movie/show/album/series)
                    stats[key] = len([d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))])
            except Exception:
                pass

        return stats

    def restart_services(self):
        """Restart all MediaHub services"""
        try:
            subprocess.run(
                ['docker', 'compose', 'restart'],
                cwd=INSTALL_DIR, timeout=120
            )
            return True
        except Exception:
            return False

    def update_containers(self):
        """Update all containers"""
        try:
            subprocess.Popen(
                [f'{INSTALL_DIR}/update.sh'],
                cwd=INSTALL_DIR
            )
            return True
        except Exception:
            return False

    def create_backup(self):
        """Create system backup"""
        try:
            subprocess.Popen(
                [f'{INSTALL_DIR}/scripts/backup-config.sh', '--quick'],
                cwd=INSTALL_DIR
            )
            return True
        except Exception:
            return False

    def reboot_system(self):
        """Reboot the Raspberry Pi"""
        try:
            subprocess.Popen(['sudo', 'reboot'])
            return True
        except Exception:
            return False

    def manage_service(self, container, action):
        """Manage a specific service"""
        valid_actions = ['start', 'stop', 'restart']
        if action not in valid_actions:
            return False

        try:
            subprocess.run(
                ['docker', action, container],
                timeout=60
            )
            return True
        except Exception:
            return False

    def send_notification(self, title, message):
        """Send a notification via the notification system"""
        try:
            subprocess.run(
                [f'{INSTALL_DIR}/scripts/notify.sh', title, message],
                timeout=10
            )
            return True
        except Exception:
            return False

    def get_packs_info(self):
        """Get information about available packs"""
        current_pack = 'unknown'
        pack_file = Path(f'{INSTALL_DIR}/.current_pack')
        if pack_file.exists():
            current_pack = pack_file.read_text().strip()

        # Count running services
        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', '{{.Names}}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            running_services = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        except Exception:
            running_services = 0

        return {
            'current': current_pack,
            'running_services': running_services,
            'available': [
                {
                    'name': 'minimal',
                    'label': 'Minimal',
                    'services': 7,
                    'ram': '1.5GB',
                    'description': 'Basic streaming (VPN, Downloads, Jellyfin)'
                },
                {
                    'name': 'essential',
                    'label': 'Essential',
                    'services': 15,
                    'ram': '3GB',
                    'description': 'Standard setup with management tools'
                },
                {
                    'name': 'full',
                    'label': 'Full',
                    'services': 30,
                    'ram': '6GB',
                    'description': 'All features including monitoring'
                }
            ]
        }

    def switch_pack(self, pack_name):
        """Switch to a different installation pack"""
        valid_packs = ['minimal', 'essential', 'full']
        if pack_name not in valid_packs:
            return False

        try:
            subprocess.Popen(
                [f'{INSTALL_DIR}/scripts/manage-packs.sh', 'switch', pack_name],
                cwd=INSTALL_DIR
            )
            return True
        except Exception:
            return False


def run_server():
    """Start the TV Admin server"""
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    server_address = ('', PORT)
    httpd = HTTPServer(server_address, MediaHubAPIHandler)

    print(f'MediaHub TV Admin Server running on port {PORT}')
    print(f'Access at: http://localhost:{PORT}')

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nServer stopped.')


if __name__ == '__main__':
    run_server()
