# HHFTechnology Media Server Installation Script

An automated installation script for setting up a complete media server stack on Linux systems. This script simplifies the installation and configuration of popular media management applications.

# ⚠️ Important Cautions

- **Limited RAM Systems**: If your system has limited RAM (less than 4GB), install applications one by one rather than all at once to prevent system instability.

- **Beta Features**: FlareSolverr and Overseerr integrations are currently in testing phase. Use these features at your own risk as they may contain bugs or unexpected behavior.

## 🚀 Features

- One-click installation of multiple media server applications
- Automatic service configuration and management
- Secure default settings
- User and group permission management
- Systematic backup and restore functionality
- Interactive menu interface
- Comprehensive logging
- Error handling and recovery
- System compatibility checks

## 📋 Included Applications

| Application | Description | Default Port |
|-------------|-------------|--------------|
| Jackett | Index aggregator/proxy | 9117 |
| Sonarr | TV series management | 8989 |
| Radarr | Movie management | 7878 |
| Lidarr | Music management | 8686 |
| Readarr | Book management | 8787 |
| Prowlarr | Index manager | 9696 |
| Bazarr | Subtitle management | 6767 |
| qBittorrent-nox | Torrent client (headless) | 8080 |
| FlareSolverr | Cloudflare bypass | 8191 |
| Overseerr | Request management | 5055 |

## 💻 System Requirements

- Debian-based Linux distribution (Ubuntu, Debian, etc.)
- Root/sudo access
- Supported architectures:
  - x86_64 (AMD64)
  - aarch64 (ARM64)
  - armv7l (ARM32)
- Minimum 2GB RAM
- 20GB available disk space

## 🔧 Installation

### Quick Install

```bash
# Download the installer
wget -O - https://raw.githubusercontent.com/hhftechnology/media-server/main/get-hhf-installer.sh | sudo bash

# Run the installation script
sudo hhf-media-install
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/hhftechnology/media-server.git
```

2. Make the script executable:
```bash
chmod +x get-hhf-installer.sh
```

3. Run the installer:
```bash
sudo ./get-hhf-installer.sh
```

## 📚 Usage

The installation script provides an interactive menu with the following options:

### Installation Options
- Install ALL applications
- Individual application installation
- Custom installation combinations

### Removal Options
- Remove ALL applications
- Individual application removal
- Clean uninstallation with configuration removal

### Maintenance Options
- Show active services
- Display default ports
- Show application sources
- System status monitoring
- Backup management
- Restore from backup

### Other Options
- Script updates
- Exit

## 🛠️ Configuration

Default installation paths:
- Application binaries: `/opt/<ApplicationName>`
- Configuration files: `/var/lib/<application>/.config/<ApplicationName>`
- Download directory (qBittorrent): `/var/lib/qbittorrent-nox/Downloads`

Default credentials:
- qBittorrent WebUI: 
  - Username: `admin`
  - Password: `adminadmin`

## 🔒 Security

The script implements several security measures:
- Creates dedicated service users for each application
- Establishes a media group for shared access
- Sets appropriate file permissions
- Uses systemd service isolation
- Configures secure default settings

## 📝 Logging

- Installation logs: `/var/lib/hhf-installer/install.log`
- State tracking: `/var/lib/hhf-installer/install_state`
- Backup directory: `/var/lib/hhf-installer/backups`

## 🔄 Backup and Restore

### Creating Backups
The script automatically creates backups before major operations. Manual backups can be created through the maintenance menu.

### Restoring from Backup
Use the maintenance menu to restore from the most recent backup or specify a particular backup to restore.

## 🐛 Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs: `journalctl -u <service-name>`
   - Verify permissions: `ls -l /opt/<ApplicationName>`
   - Ensure ports are available: `netstat -tulpn`

2. **Permission Issues**
   - Verify user/group membership
   - Check directory permissions
   - Review service user settings

3. **Network Access**
   - Confirm port availability
   - Check firewall settings
   - Verify network connectivity

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📮 Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review the installation logs
3. Open an issue on GitHub
4. Join our community discussions

## 🙏 Acknowledgments

- Thanks to all the amazing projects that make this media server stack possible
- Community contributors and testers
- Open source software maintainers

## ⚠️ Disclaimer

This script is provided as-is. Always review scripts before running them with root privileges. Users are responsible for complying with all applicable laws and regulations regarding media consumption and distribution.
