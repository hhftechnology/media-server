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

        # Handle different applications
        case "${app_name}" in
            bazarr)
                setup_bazarr_dependencies
                wget -O "${TEMPDIR}/${app_name}.zip" -q --show-progress "${src_url}" || 
                    error_exit "Failed to download ${app_name}"
                task_pass "Source file downloaded. SHA256: $(sha256sum ${TEMPDIR}/${app_name}.zip | cut -d ' ' -f 1)"

                task_info "Extracting ${app_name} to ${app_opt_path}..."
                mkdir -p "${app_opt_path}"
                unzip -q "${TEMPDIR}/${app_name}.zip" -d "${app_opt_path}" || 
                    error_exit "Failed to extract Bazarr"
                
                task_info "Setting up Python virtual environment for Bazarr..."
                python3 -m venv "${app_opt_path}/venv" || 
                    error_exit "Failed to create Python virtual environment"
                
                . "${app_opt_path}/venv/bin/activate" || 
                    error_exit "Failed to activate Python virtual environment"
                
                pip install -r "${app_opt_path}/requirements.txt" || 
                    error_exit "Failed to install Python requirements"
                
                deactivate
                ;;

            flaresolverr)
                setup_flaresolverr_dependencies
                mkdir -p "${app_opt_path}"
        
                # Download tar.gz file
                wget -O "${TEMPDIR}/${app_name}.tar.gz" -q --show-progress "${src_url}" || 
                    error_exit "Failed to download ${app_name}"
            
                # Extract the tar.gz file
                tar xzf "${TEMPDIR}/${app_name}.tar.gz" -C "${app_opt_path}" || 
                    error_exit "Failed to extract ${app_name}"
        
                # Find the actual binary in the extracted contents
                    BINARY=$(find "${app_opt_path}" -type f -executable -name "flaresolverr")
                if [ -z "${BINARY}" ]; then
                    error_exit "Could not find flaresolverr executable in extracted contents"
                fi
        
                # Update the service file to point to the correct binary location
                BINARY_PATH="${BINARY}"
        
                task_pass "Binary extracted and located successfully at ${BINARY_PATH}"
                ;;

            overseerr)
                setup_overseerr_dependencies
                wget -O "${TEMPDIR}/${app_name}.tar.gz" -q --show-progress "${src_url}" || 
                    error_exit "Failed to download ${app_name}"
                task_pass "Source file downloaded. SHA256: $(sha256sum ${TEMPDIR}/${app_name}.tar.gz | cut -d ' ' -f 1)"

                mkdir -p "${app_opt_path}"
                tar -xf "${TEMPDIR}/${app_name}.tar.gz" -C "${app_opt_path}" || 
                    error_exit "Failed to extract ${app_name}"
                
                cd "${app_opt_path}" || error_exit "Failed to change to overseerr directory"
                npm install --production || error_exit "Failed to install Overseerr dependencies"
                ;;

            *)
                wget -O "${TEMPDIR}/${app_name}.tar.gz" -q --show-progress "${src_url}" || 
                    error_exit "Failed to download ${app_name}"
                task_pass "Source file downloaded. SHA256: $(sha256sum ${TEMPDIR}/${app_name}.tar.gz | cut -d ' ' -f 1)"

                task_info "Extracting ${app_name} to ${app_opt_path}..."
                mkdir -p "${app_opt_path}"
                tar -xf "${TEMPDIR}/${app_name}.tar.gz" -C "/opt/" || 
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

        # Configure systemd service
        task_info "Creating systemd service..."
        
        case "${app_name}" in
            bazarr)
                cat > "/etc/systemd/system/${app_name}.service" << EOF
# Generated by HHFTechnology Install Script ${date_stamp}
[Unit]
Description=Bazarr Daemon
After=network.target

[Service]
WorkingDirectory=${app_opt_path}
User=${app_user}
Group=${app_group}
UMask=0002
ExecStart=${app_opt_path}/venv/bin/python ${app_opt_path}/bazarr.py
Restart=on-failure
RestartSec=5
Type=simple
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
                ;;

            flaresolverr)
                cat > "/etc/systemd/system/${app_name}.service" << EOF
[Unit]
Description=FlareSolverr Daemon
After=network.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
Type=simple
User=${app_user}
Group=${app_group}
UMask=0002
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=NODE_ENV=production
Environment=LOG_LEVEL=debug
Environment=LOG_HTML=false
Environment=CAPTCHA_SOLVER=none
Environment=PORT=8191
Environment=HOST=0.0.0.0
Environment=BROWSER_TIMEOUT=40000
Environment=CHROME_BIN=/usr/bin/chromium-browser
Environment=CHROME_PATH=/usr/lib/chromium/
ExecStart=${BINARY_PATH}
WorkingDirectory=${app_opt_path}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
                ;;


            overseerr)
                cat > "/etc/systemd/system/${app_name}.service" << EOF
# Generated by HHFTechnology Install Script ${date_stamp}
[Unit]
Description=Overseerr Daemon
After=network.target

[Service]
WorkingDirectory=${app_opt_path}
User=${app_user}
Group=${app_group}
UMask=0002
Type=simple
ExecStart=npm start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
                ;;

            *)
                cat > "/etc/systemd/system/${app_name}.service" << EOF
# Generated by HHFTechnology Install Script ${date_stamp}
[Unit]
Description=$(title_case ${app_name}) Daemon
After=network.target

[Service]
WorkingDirectory=${app_opt_path}
User=${app_user}
Group=${app_group}
UMask=0002
Type=simple
ExecStart=${app_opt_path}/$(title_case ${app_name})
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
                ;;
        esac

        # Enable and start service
        systemctl daemon-reload
        systemctl enable "${app_name}" || error_exit "Failed to enable ${app_name} service"
        systemctl start "${app_name}" || error_exit "Failed to start ${app_name} service"
        
        if [ "$(systemctl is-active ${app_name})" = "active" ]; then
            task_pass "${app_name} service started successfully"
            case "${app_name}" in
                flaresolverr)
                    task_info "FlareSolverr is available at: http://localhost:8191"
                    task_info "Add to Prowlarr FlareSolverr settings: http://localhost:8191"
                    ;;
                overseerr)
                    task_info "Overseerr is available at: http://localhost:5055"
                    task_info "Complete the setup by visiting http://localhost:5055"
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