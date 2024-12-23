### SYSTEM DETECTION ###

detect_system() {
    # CPU/Board Info Detection
    if [ -f "/proc/cpuinfo" ]; then
        cpuBoardInfo=$(awk -F': ' '/model name|Model/ {print $2; exit}' /proc/cpuinfo)
    elif command -v sysctl >/dev/null 2>&1; then
        cpuBoardInfo=$(sysctl -n hw.model 2>/dev/null)
    fi

    # OS Detection
    if command -v lsb_release >/dev/null 2>&1; then
        osInfo=$(lsb_release -d --short)
    elif [ -f "/etc/os-release" ]; then
        osInfo=$(. /etc/os-release && echo "${PRETTY_NAME}")
    fi

    # Kernel and Architecture Detection
    if command -v uname >/dev/null 2>&1; then
        arch=$(uname -m)
        kernel=$(uname -r)
        kname=$(uname -s)
        [ -z "${osInfo}" ] && osInfo="${kname}"
        kernelInfo="${kernel}"
        archInfo="${arch}"
    fi

    task_info "System Information:"
    task_info "CPU/Board: ${cpuBoardInfo}"
    task_info "OS: ${osInfo} ${kernelInfo}"
    task_info "Architecture: ${archInfo}"

    # Architecture Detection for Application Downloads
    case "${arch}" in
        *x86_64*|*X86_64*|*amd64*|*AMD64*)
            JACKETT_ARCH="AMDx64"
            SERVARR_ARCH="x64"
            ;;
        *aarch64*|*AARCH64*|*arm64*|*ARM64*)
            JACKETT_ARCH="ARM64"
            SERVARR_ARCH="arm64"
            ;;
        *armv7l*|*ARMV7L*)
            JACKETT_ARCH="ARM32"
            SERVARR_ARCH="arm"
            ;;
        *)
            error_exit "Unsupported architecture: ${arch}"
            ;;
    esac

    # Validate Linux-based OS
    case "$(uname -s)" in
        *Linux*)
            task_pass "Linux-based OS detected"
            ;;
        *)
            if [ -f "/etc/os-release" ] && grep -qi "linux" /etc/os-release; then
                task_pass "Linux-based OS detected"
            else
                error_exit "Linux required. Not detected."
            fi
            ;;
    esac
}

# Function to fetch latest application URLs
get_application_urls() {
    # Fetch latest jackett release
    if command -v curl >/dev/null 2>&1; then
        jackett_latest=$(curl -s https://github.com/Jackett/Jackett/releases | 
            sed -n 's/.*href="\([^"]*\).*/\1/p' | 
            grep Linux${JACKETT_ARCH}.tar.gz -A 0 | 
            head -n 1)
        jackett_src_url="https://github.com${jackett_latest}"
    else
        jackett_latest=$(wget -qO- https://github.com/Jackett/Jackett/releases | 
            sed -n 's/.*href="\([^"]*\).*/\1/p' | 
            grep Linux${JACKETT_ARCH}.tar.gz -A 0 | 
            head -n 1)
        jackett_src_url="https://github.com${jackett_latest}"
    fi

    # Set Servarr application URLs
    radarr_src_url="https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
    lidarr_src_url="https://lidarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
    prowlarr_src_url="http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
    readarr_src_url="http://readarr.servarr.com/v1/update/develop/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
    sonarr_src_url="https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=${SERVARR_ARCH}"
    bazarr_src_url="https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip"
    # Add FlareSolverr URL
    case "${SERVARR_ARCH}" in
        "x64")
            flaresolverr_src_url="https://github.com/FlareSolverr/FlareSolverr/releases/download/v3.3.21/flaresolverr_linux_x64.tar.gz"
            ;;
        "arm64")
            flaresolverr_src_url="https://github.com/FlareSolverr/FlareSolverr/releases/download/v3.3.21/flaresolverr_linux_arm64.tar.gz"
            ;;
        "arm")
            flaresolverr_src_url="https://github.com/FlareSolverr/FlareSolverr/releases/download/v3.3.21/flaresolverr_linux_armv7.tar.gz"
            ;;
    esac
    # Add Overseerr URL
    overseerr_src_url="https://github.com/sct/overseerr/archive/refs/tags/v1.33.2.tar.gz"
    qbittorrent_nox_src_url="Installed via package manager"
}

banner_info() {
    printf '%s\n' "
    ${BLUE}██╗  ██╗██╗  ██╗███████╗${RED}████████╗███████╗ ██████╗██╗  ██╗
    ${BLUE}██║  ██║██║  ██║██╔════╝${RED}╚══██╔══╝██╔════╝██╔════╝██║  ██║
    ${BLUE}███████║███████║█████╗  ${RED}   ██║   █████╗  ██║     ███████║
    ${BLUE}██╔══██║██╔══██║██╔══╝  ${RED}   ██║   ██╔══╝  ██║     ██╔══██║
    ${BLUE}██║  ██║██║  ██║██║     ${RED}   ██║   ███████╗╚██████╗██║  ██║
    ${BLUE}╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ${RED}   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝${RESET}
    "
}