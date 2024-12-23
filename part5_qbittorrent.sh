# qBittorrent installation function
setup_qbittorrent_nox() {
    date_stamp="$(date '+%Y-%m-%d %H%M')"
    app_name="qbittorrent-nox"
    app_user="${app_name}"
    app_lib_path="/var/lib/${app_name}"
    app_config_path="${app_lib_path}/.config/qBittorrent"
    app_group="media"
    
    task_info "Setting up ${app_name}..."
    
    # Create service user
    if ! id "${app_user}" >/dev/null 2>&1; then
        useradd -s /usr/sbin/nologin -d "/var/lib/${app_user}" -r -m -U "${app_user}" || 
            error_exit "Failed to create user ${app_user}"
    fi
    
    # Create media group if it doesn't exist
    if ! getent group "${app_group}" >/dev/null 2>&1; then
        groupadd "${app_group}" || error_exit "Failed to create group ${app_group}"
    fi
    
    # Add service user to media group
    if ! id "${app_user}" | grep -q "${app_group}"; then
        usermod -a -G "${app_group}" "${app_user}" || 
            error_exit "Failed to add ${app_user} to ${app_group} group"
    fi
    
    # Add actual user to media group
    actual_user="${SUDO_USER:-$USER}"
    if ! id "${actual_user}" | grep -q "${app_group}"; then
        usermod -a -G "${app_group}" "${actual_user}" || 
            error_exit "Failed to add ${actual_user} to ${app_group} group"
    fi
    
    # Install qBittorrent
    task_info "Installing ${app_name}..."
    pkg_install qbittorrent-nox
    
    # Create necessary directories
    mkdir -p "${app_lib_path}/Downloads"
    mkdir -p "${app_config_path}"
    
    # Set permissions
    task_start "Setting permissions..."
    chown -R "${app_user}:${app_group}" "${app_lib_path}"
    chmod -R 775 "${app_lib_path}"
    check_result
    
    # Create systemd service
    task_info "Creating systemd service..."
    cat > "/etc/systemd/system/${app_name}.service" <<EOF
# Generated by HHFTechnology Install Script ${date_stamp}
[Unit]
Description=qBittorrent-nox Daemon
After=network.target

[Service]
Type=forking
User=${app_user}
Group=${app_group}
UMask=0002
ExecStart=/usr/bin/qbittorrent-nox -d --webui-port=8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "${app_name}" || error_exit "Failed to enable ${app_name} service"
    systemctl start "${app_name}" || error_exit "Failed to start ${app_name} service"
    
    if [ "$(systemctl is-active ${app_name})" = "active" ]; then
        task_pass "${app_name} service started successfully"
        task_info "Default qBittorrent credentials: admin / adminadmin"
        task_info "Default download directory: ${app_lib_path}/Downloads"
        task_info "WebUI available at: http://localhost:8080"
    else
        task_fail "${app_name} service failed to start"
    fi
}

# qBittorrent removal function
remove_qbittorrent_nox() {
    app_name="qbittorrent-nox"
    app_lib_path="/var/lib/${app_name}"
    
    task_warn "Preparing to remove ${app_name}..."
    check_continue
    
    # Stop and disable service
    task_info "Stopping ${app_name} service..."
    systemctl stop "${app_name}" 2>/dev/null
    systemctl disable "${app_name}" 2>/dev/null
    
    # Remove package
    pkg_remove qbittorrent-nox
    
    # Remove user and directories
    if id "${app_name}" >/dev/null 2>&1; then
        task_info "Removing ${app_name} user..."
        deluser "${app_name}" 2>/dev/null
    fi
    
    if [ -d "${app_lib_path}" ]; then
        task_info "Removing ${app_lib_path}..."
        rm -rf "${app_lib_path}"
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/${app_name}.service" ]; then
        rm "/etc/systemd/system/${app_name}.service"
    fi
    
    systemctl daemon-reload
    task_pass "${app_name} removed successfully"
}