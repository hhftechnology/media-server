# Application dependencies setup functions
setup_dependencies() {
    task_info "Installing core dependencies..."
    pkg_install curl unzip apt-transport-https dirmngr gnupg ca-certificates
    task_info "Installing media dependencies..."
    pkg_install mono-complete mediainfo sqlite3 libmono-cil-dev libchromaprint-tools
}

setup_bazarr_dependencies() {
    task_info "Installing Bazarr dependencies..."
    pkg_install python3-dev python3-pip python3-libxml2 python3-lxml unrar-free unar ffmpeg libxml2-dev libxslt1-dev libatlas-base-dev
    
    python_version=$(python3 -V 2>&1 | grep -Po '(?<=Python )\d+\.\d+')
    if ! pkg_install "python${python_version}-venv"; then
        pkg_install python3-venv
    fi
}

setup_flaresolverr_dependencies() {
    task_info "Installing FlareSolverr dependencies..."
    if ! command -v node >/dev/null 2>&1; then
        task_info "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        pkg_install nodejs
    fi
    pkg_install chromium-browser chromium-chromedriver
}

setup_overseerr_dependencies() {
    task_info "Installing Overseerr dependencies..."
    if ! command -v node >/dev/null 2>&1; then
        task_info "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        pkg_install nodejs
    fi
}

# Main application setup function
setup_app() {
    clear
    make_temp_dir
    setup_dependencies

    for app in "$@"; do
        if [ "$(systemctl is-active "${app}")" = "active" ]; then
            task_skip "Service ${app} already exists and is active"
            continue
        fi

        date_stamp="$(date '+%Y-%m-%d %H%M')"
        app_name="$(lower_case "${app}")"
        app_opt_path="/opt/$(title_case ${app_name})"
        app_lib_path="/var/lib/${app}"
        app_config_path="/var/lib/${app_name}/.config/$(title_case ${app_name})"

        # Set file extension and handle dependencies
        case "${app}" in
            bazarr)
                setup_bazarr_dependencies
                file_extension="zip"
                ;;
            flaresolverr)
                setup_flaresolverr_dependencies
                file_extension="tar.gz"
                ;;
            overseerr)
                setup_overseerr_dependencies
                file_extension="tar.gz"
                ;;
            *)
                file_extension="tar.gz"
                ;;
        esac

        # User and group setup
        app_user="${app_name}"
        app_group="media"

        task_info "Setting up ${app_name}..."

        # Create service user
        task_start "Creating service user ${app_user}..."
        if ! id "${app_user}" >/dev/null 2>&1; then
            useradd -s /usr/sbin/nologin -d "/var/lib/${app_user}" -r -m -U "${app_user}" || 
                error_exit "Failed to create user ${app_user}"
        fi
        task_pass

        # Create media group
        task_start "Creating media group..."
        if ! getent group "${app_group}" >/dev/null 2>&1; then
            groupadd "${app_group}" || error_exit "Failed to create group ${app_group}"
        fi
        task_pass

        # Add user to media group
        task_start "Adding ${app_user} to media group..."
        if ! id "${app_user}" | grep -q "${app_group}"; then
            usermod -a -G "${app_group}" "${app_user}" || 
                error_exit "Failed to add ${app_user} to ${app_group} group"
        fi
        task_pass

        # Add actual user to media group
        actual_user="${SUDO_USER:-$USER}"
        task_start "Adding ${actual_user} to media group..."
        if ! id "${actual_user}" | grep -q "${app_group}"; then
            usermod -a -G "${app_group}" "${actual_user}" || 
                error_exit "Failed to add ${actual_user} to ${app_group} group"
        fi
        task_pass

        # Download and extract application
        src_url_var="${app_name}_src_url"
        src_url=$(eval echo \$"${src_url_var}")
        task_info "Download source URL: ${src_url}"

        wget -O "${TEMPDIR}/${app_name}.${file_extension}" -q --show-progress "${src_url}" || 
            error_exit "Failed to download ${app_name}"

        task_pass "Source file downloaded. SHA256: $(sha256sum ${TEMPDIR}/${app_name}.${file_extension} | cut -d ' ' -f 1)"

        task_info "Extracting ${app_name} to ${app_opt_path}..."
        mkdir -p "${app_opt_path}"

        case "${app}" in
            bazarr)
                unzip -q "${TEMPDIR}/${app_name}.${file_extension}" -d "${app_opt_path}" || 
                    error_exit "Failed to extract Bazarr"
                
                task_info "Setting up Python virtual environment for Bazarr..."
                python3 -m venv "${app_opt_path}/venv" || 
                    error_exit "Failed to create Python virtual environment"
                
                # Activate venv and install requirements
                . "${app_opt_path}/venv/bin/activate" || 
                    error_exit "Failed to activate Python virtual environment"
                
                pip install -r "${app_opt_path}/requirements.txt" || 
                    error_exit "Failed to install Python requirements"
                
                deactivate
                ;;
                
            flaresolverr)
                tar -xf "${TEMPDIR}/${app_name}.${file_extension}" -C "${app_opt_path}" || 
                    error_exit "Failed to extract ${app_name}"
                npm install --prefix "${app_opt_path}" || 
                    error_exit "Failed to install FlareSolverr dependencies"
                ;;
                
            overseerr)
                tar -xf "${TEMPDIR}/${app_name}.${file_extension}" -C "${app_opt_path}" || 
                    error_exit "Failed to extract ${app_name}"
                npm install --prefix "${app_opt_path}" || 
                    error_exit "Failed to install Overseerr dependencies"
                ;;
                
            *)
                tar -xf "${TEMPDIR}/${app_name}.${file_extension}" -C "/opt/" || 
                    error_exit "Failed to extract ${app_name}"
                ;;
        esac

        # Set permissions
        task_start "Setting permissions..."
        chown -R "${app_user}:${app_group}" "${app_opt_path}"
        chmod -R 775 "${app_opt_path}"
        
        mkdir -p "${app_config_path}"
        chown -R "${app_user}:${app_group}" "${app_lib_path}"
        chmod -R 775 "${app_lib_path}"
        task_pass

        # Configure service execution
        case "${app_name}" in
            jackett)
                app_exec="${app_opt_path}/${app_name}_launcher.sh"
                ;;
            sonarr)
                app_exec="${app_opt_path}/$(title_case ${app_name}) -nobrowser -data=${app_lib_path}"
                ;;
            bazarr)
                app_exec="${app_opt_path}/venv/bin/python ${app_opt_path}/bazarr.py"
                ;;
            flaresolverr)
                app_exec="${app_opt_path}/bin/flaresolverr"
                app_port="8191"
                ;;
            overseerr)
                app_exec="npm --prefix ${app_opt_path} start"
                app_port="5055"
                ;;
            *)
                app_exec="${app_opt_path}/$(title_case ${app_name})"
                ;;
        esac

        # Create systemd service
        task_info "Creating systemd service for ${app_name}..."
        cat > "/etc/systemd/system/${app_name}.service" << EOF
# Generated by HHFTechnology Install Script ${date_stamp}
[Unit]
Description=$(title_case ${app_name}) Daemon
After=syslog.target network.target

[Service]
WorkingDirectory=${app_opt_path}
User=${app_user}
Group=${app_group}
UMask=0002
SyslogIdentifier=${app_name}
Restart=on-failure
RestartSec=5
Type=simple
ExecStart=${app_exec}
KillSignal=SIGINT
TimeoutStopSec=20
ExecStartPre=/bin/sleep 10

[Install]
WantedBy=multi-user.target
EOF

        # Enable and start service
        systemctl daemon-reload
        systemctl enable "${app_name}" || error_exit "Failed to enable ${app_name} service"
        systemctl start "${app_name}" || error_exit "Failed to start ${app_name} service"
        
        if [ "$(systemctl is-active ${app_name})" = "active" ]; then
            task_pass "${app_name} service started successfully"
            case "${app_name}" in
                flaresolverr)
                    task_info "FlareSolverr is available at: http://localhost:${app_port}"
                    task_info "Add to Prowlarr FlareSolverr settings: http://localhost:${app_port}"
                    ;;
                overseerr)
                    task_info "Overseerr is available at: http://localhost:${app_port}"
                    task_info "Complete the setup by visiting http://localhost:${app_port}"
                    ;;
            esac
        else
            task_fail "${app_name} service failed to start"
        fi

        task_info "Completed installation of ${app_name}"
    done

    remove_temp_dir
}

# Application removal function
remove_app() {
    clear
    for app in "$@"; do
        app=$(lower_case "${app}")
        app_opt_path="/opt/$(title_case "${app}")"
        app_lib_path="/var/lib/${app}"
        
        task_warn "Preparing to remove ${app}..."
        check_continue

        # Stop and disable service
        task_info "Stopping ${app} service..."
        systemctl stop "${app}" 2>/dev/null
        systemctl disable "${app}" 2>/dev/null

        # Remove app directory
        if [ -d "${app_opt_path}" ]; then
            task_info "Removing ${app_opt_path}..."
            rm -rf "${app_opt_path}"
        fi

        # Remove configuration and data
        if [ -d "${app_lib_path}" ]; then
            task_info "Removing ${app_lib_path}..."
            rm -rf "${app_lib_path}"
        fi

        # Remove service file
        if [ -f "/etc/systemd/system/${app}.service" ]; then
            task_info "Removing service file..."
            rm "/etc/systemd/system/${app}.service"
        fi

        # Remove user
        if id "${app}" >/dev/null 2>&1; then
            task_info "Removing ${app} user..."
            deluser "${app}" 2>/dev/null
        fi

        systemctl daemon-reload
        task_pass "${app} removed successfully"
    done
}