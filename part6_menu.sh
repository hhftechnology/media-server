# Service status checking functions
active_services() {
    task_info "Checking active services..."
    for app in ${APPLIST}; do
        if [ "$(systemctl is-active "${app}")" = "active" ]; then
            task_pass "${app} service is active and running"
            case "${app}" in
                flaresolverr)
                    if curl -s http://localhost:8191/health >/dev/null; then
                        task_info "FlareSolverr is responding on port 8191"
                    else
                        task_warn "FlareSolverr is not responding"
                    fi
                    ;;
                overseerr)
                    if curl -s http://localhost:5055/api/v1/status >/dev/null; then
                        task_info "Overseerr is responding on port 5055"
                    else
                        task_warn "Overseerr is not responding"
                    fi
                    ;;
            esac
        else
            task_warn "${app} service is not active"
        fi
    done
}

check_service() {
    if [ -z "$1" ]; then
        error_exit "No service name provided to check"
    fi
    
    task_start "Checking service status for ${1}..."
    if [ "$(systemctl is-active "$1")" = "active" ]; then
        task_pass "${1} is active"
        return 0
    else
        task_fail "${1} is not active"
        return 1
    fi
}

# Default ports information
default_ports() {
    task_info "Default Application Ports"
    cat << EOF | while read line; do task_info "${line}"; done
Jackett:         http://localhost:9117
Sonarr:          http://localhost:8989
Lidarr:          http://localhost:8686
Radarr:          http://localhost:7878
Readarr:         http://localhost:8787
Prowlarr:        http://localhost:9696
Bazarr:          http://localhost:6767
qBittorrent-nox: http://localhost:8080
FlareSolverr:    http://localhost:8191
Overseerr:       http://localhost:5055
EOF
}

# Display backup information
show_backups() {
    local backup_dir="/var/lib/hhf-installer/backups"
    if [ -d "$backup_dir" ]; then
        task_info "Available Backups:"
        ls -lht "$backup_dir" | grep -v '^total' | while read -r line; do
            task_info "$line"
        done
    else
        task_warn "No backups found"
    fi
}

# Display system status
system_status() {
    task_info "System Status Information"
    task_info "------------------------"
    
    # CPU Usage
    task_info "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
    
    # Memory Usage
    task_info "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
    
    # Disk Usage
    task_info "Disk Usage: $(df -h / | awk 'NR==2{print $5}')"
    
    # System Load
    task_info "System Load: $(uptime | awk -F'load average:' '{print $2}')"
    
    # Service Status
    task_info "\nService Status:"
    active_services
}

# Main menu display
display_menu() {
    clear
    banner_info
    printf '%s\n' "
    ${BOLD}=================
     Menu Options 
    =================${RESET}

    Installation Options:
    1.  Install ALL applications
    2.  Install jackett
    3.  Install sonarr
    4.  Install lidarr
    5.  Install radarr
    6.  Install readarr
    7.  Install prowlarr
    8.  Install bazarr
    9.  Install qbittorrent-nox
    10. Install FlareSolverr
    11. Install Overseerr

    Removal Options:
    12. Remove ALL applications
    13. Remove jackett
    14. Remove sonarr
    15. Remove lidarr
    16. Remove radarr
    17. Remove readarr
    18. Remove prowlarr
    19. Remove bazarr
    20. Remove qbittorrent-nox
    21. Remove FlareSolverr
    22. Remove Overseerr

    Maintenance Options:
    23. Show active services
    24. Show default ports
    25. Show application sources
    26. Show system status
    27. Show backups
    28. Create backup
    29. Restore from backup

    Other Options:
    30. Update script
    31. Exit

    "
    printf "    Enter option [1-31]: "

    while :; do
        read -r choice
        case ${choice} in
            1)
                setup_app jackett sonarr lidarr radarr readarr prowlarr bazarr flaresolverr overseerr
                ;;
            2)
                setup_app jackett
                ;;
            3)
                setup_app sonarr
                ;;
            4)
                setup_app lidarr
                ;;
            5)
                setup_app radarr
                ;;
            6)
                setup_app readarr
                ;;
            7)
                setup_app prowlarr
                ;;
            8)
                setup_app bazarr
                ;;
            9)
                setup_qbittorrent_nox
                ;;
            10)
                setup_app flaresolverr
                ;;
            11)
                setup_app overseerr
                ;;
            12)
                remove_app jackett sonarr lidarr radarr readarr prowlarr bazarr flaresolverr overseerr
                ;;
            13)
                remove_app jackett
                ;;
            14)
                remove_app sonarr
                ;;
            15)
                remove_app lidarr
                ;;
            16)
                remove_app radarr
                ;;
            17)
                remove_app readarr
                ;;
            18)
                remove_app prowlarr
                ;;
            19)
                remove_app bazarr
                ;;
            20)
                remove_qbittorrent_nox
                ;;
            21)
                remove_app flaresolverr
                ;;
            22)
                remove_app overseerr
                ;;
            23)
                clear
                active_services
                ;;
            24)
                clear
                default_ports
                ;;
            25)
                clear
                check_sources
                ;;
            26)
                clear
                system_status
                ;;
            27)
                clear
                show_backups
                ;;
            28)
                clear
                backup_files
                ;;
            29)
                clear
                restore_from_backup
                ;;
            30)
                clear
                self_update
                ;;
            31)
                printf "\nExiting...\n"
                exit 0
                ;;
            *)
                clear
                display_menu
                ;;
        esac
        
        if [ ${choice} -ne 31 ]; then
            printf "\nOperation completed. Press Enter to return to menu..."
            read -r
            clear
            display_menu
        fi
    done
}

# Check for script updates
self_update() {
    task_info "Checking for script updates..."
    
    # Implement version check and update logic here
    # This would check against your repository for newer versions
    
    task_info "Current version: ${SCRIPT_VERSION}"
    task_warn "Auto-update functionality will be implemented in future versions"
    task_info "Please check https://github.com/hhftechnology/media-server for updates"
}

# Initialize script
init_script() {
    check_superuser # Changed from check_root to check_superuser
    detect_system
    get_application_urls
    display_menu
}