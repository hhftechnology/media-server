script_info() {
    banner_info
    printf '%s\n' "
    ${BOLD}HHFTechnology Media Server Installation Script v${SCRIPT_VERSION}${RESET}

    Description:    Automated installer for Jackett, Sonarr, Radarr, Lidarr, 
                   Readarr, Prowler, Bazarr, and qBittorrent-nox
                   
    Compatibility: - Raspberry Pi 3/4 (64-bit)
                  - Debian-based Linux distributions (64-bit)
                  - Ubuntu Server/Desktop (64-bit)

    Author:         github.com/hhftechnology

    Notes:          - Requires sudo/root permissions
                   - Performs system updates before installation
                   - Creates dedicated user accounts and media group
                   - Configures systemd services for automatic startup
                   - Sets appropriate file permissions
                   - Provides web-based management interface

    Default Ports:  Jackett (9117), Sonarr (8989), Radarr (7878)
                   Lidarr (8686), Readarr (8787), Prowlarr (9696)
                   Bazarr (6767), qBittorrent (8080)
    "
}

# Interactive user prompts
check_continue() {
    local response
    while true; do
        read -r -p "[${GREEN}USER${RESET}] Do you wish to continue (y/N)? " response
        case "${response}" in
            [yY][eE][sS]|[yY])
                echo
                return 0
                ;;
            *)
                echo
                exit 0
                ;;
        esac
    done
}

press_any_key() {
    printf "\n%s" "[${GREEN}USER${RESET}] Press enter to continue..."
    read -r ans
}

# Superuser check
check_superuser() {
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "Script must be run with sudo or as root"
    fi
}

# Package management functions
pkg_updates() {
    task_info "Updating system packages..."
    if ! apt-get update; then
        error_exit "Failed to update package lists"
    fi
    if ! apt-get upgrade -y; then
        error_exit "Failed to upgrade packages"
    fi
    apt-get --fix-broken install -y
    apt-get autoclean -y
    apt-get autoremove -y
}

pkg_install() {
    for pkg in "$@"; do
        task_start "Checking package: ${pkg}"
        if ! dpkg -s "${pkg}" >/dev/null 2>&1; then
            task_warn "Package ${pkg} not installed"
            task_info "Installing ${pkg}..."
            if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkg}"; then
                error_exit "Failed to install ${pkg}"
            fi
        else
            task_pass "Package ${pkg} already installed"
        fi
    done
}

pkg_remove() {
    for pkg in "$@"; do
        task_start "Checking package: ${pkg}"
        if dpkg -s "${pkg}" >/dev/null 2>&1; then
            task_warn "Removing package ${pkg}..."
            if ! apt-get remove -y "${pkg}"; then
                error_exit "Failed to remove ${pkg}"
            fi
        else
            task_pass "Package ${pkg} not installed"
        fi
    done
}

# Dependencies setup
setup_dependencies() {
    task_info "Installing core dependencies..."
    pkg_install curl wget unzip apt-transport-https dirmngr gnupg ca-certificates
    task_info "Installing media dependencies..."
    pkg_install mono-complete mediainfo sqlite3 libmono-cil-dev libchromaprint-tools
}

setup_bazarr_dependencies() {
    task_info "Installing Bazarr dependencies..."
    pkg_install python3-dev python3-pip python3-libxml2 python3-lxml unrar-free \
        unar ffmpeg libxml2-dev libxslt1-dev libatlas-base-dev
    
    python_version=$(python3 -V 2>&1 | grep -Po '(?<=Python )\d+\.\d+')
    if ! pkg_install "python${python_version}-venv"; then
        task_warn "Specific Python venv package not found, installing python3-venv"
        pkg_install python3-venv
    fi
}

# Application URLs check
check_sources() {
    task_info "Application Installation Source URLs"
    for app in ${APPLIST}; do
        app_var_name=$(echo "${app}" | tr '-' '_')
        src_url_var="${app_var_name}_src_url"
        src_url=$(eval echo \$"${src_url_var}")
        task_info "${app} src: ${src_url}"
    done
}