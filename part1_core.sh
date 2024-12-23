#!/bin/sh
#!/bin/sh
clear

### SET GLOBAL VARIABLES ###

TEMPDIR="/tmp/hhftechnology"
APPLIST="jackett sonarr lidarr radarr readarr prowlarr bazarr qbittorrent-nox flaresolverr overseerr"
SCRIPT_VERSION="1.0.0"

# Set terminal colors if supported
if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    MAGENTA=$(printf '\033[35m')
    CYAN=$(printf '\033[36m')
    BOLD=$(printf '\033[1m')
    RESET=$(printf '\033[0m')
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# Enhanced error handling function
error_exit() {
    task_fail "${1:-"Unknown Error"}"
    exit "${2:-1}"
}

# Temp directory management
make_temp_dir() {
    task_start "Creating temporary directory ${TEMPDIR}..."
    if ! mkdir -p "${TEMPDIR}" 2>/dev/null; then
        error_exit "Failed to create temporary directory"
    fi
    task_pass
}

remove_temp_dir() {
    task_start "Removing temporary directory and files ${TEMPDIR}..."
    if [ -d "${TEMPDIR}" ]; then
        rm -Rf "${TEMPDIR}" 2>/dev/null || task_warn "Could not remove temp directory completely"
    fi
    task_pass
}

# Logging functions
task_start() {
    printf "\r[TASK] %s$(tput el)" "${1}"
}

task_fail() {
    printf "\r[${RED}FAIL${RESET}] %s\n" "${1}"
}

task_pass() {
    printf "\r[${GREEN}PASS${RESET}] %s\n" "${1}"
}

task_skip() {
    printf "\r[${BLUE}SKIP${RESET}] %s\n" "${1}"
}

task_info() {
    printf "\r[${CYAN}INFO${RESET}] %s$(tput el)\n" "${1}"
}

task_warn() {
    printf "\r[${YELLOW}WARN${RESET}] %s$(tput el)\n" "${1}"
}

task_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        printf "\r[${MAGENTA}DEBUG${RESET}] %s$(tput el)\n" "${1}"
    fi
}

# String manipulation functions
title_case() {
    printf "%s" "${1}" | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1'
}

lower_case() {
    printf "%s" "${1}" | tr '[:upper:]' '[:lower:]'
}

upper_case() {
    printf "%s" "${1}" | tr '[:lower:]' '[:upper:]'
}

# Result checking
check_result() {
    local status=$?
    if [ ${status} -eq 0 ]; then
        task_pass "${1:-"Operation completed successfully"}"
    else
        task_fail "${1:-"Operation failed"} (Error: ${status})"
        return ${status}
    fi
}