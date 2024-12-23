#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Script URLs - Replace with your actual repository URLs
REPO_BASE="https://raw.githubusercontent.com/hhftechnology/media-server/refs/heads/main"
SCRIPT_PARTS=(
    "part1_core.sh"
    "part2_system.sh"
    "part3_package.sh"
    "part4_setup.sh"
    "part5_qbittorrent.sh"
    "part6_menu.sh"
)

# Directories and files
TEMP_DIR="/tmp/hhf-installer"
FINAL_SCRIPT="/usr/local/bin/hhf-media-install"
STATE_DIR="/var/lib/hhf-installer"
STATE_FILE="${STATE_DIR}/install_state"
BACKUP_DIR="${STATE_DIR}/backups"
LOG_FILE="${STATE_DIR}/install.log"

# Print colored status messages with logging
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "$1" | tee -a "$LOG_FILE"
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

print_status() {
    log_message "${BLUE}[INFO]${NC} $1"
}

print_success() {
    log_message "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    log_message "${RED}[ERROR]${NC} $1"
}

print_warning() {
    log_message "${YELLOW}[WARNING]${NC} $1"
}

# Initialize state tracking
init_state_tracking() {
    mkdir -p "$STATE_DIR" "$BACKUP_DIR"
    touch "$STATE_FILE"
    chmod 755 "$STATE_DIR"
    chmod 644 "$STATE_FILE"
    echo "INIT" > "$STATE_FILE"
}

# Update state
update_state() {
    echo "$1" > "$STATE_FILE"
    print_status "Installation state: $1"
}

# Get current state
get_state() {
    cat "$STATE_FILE" 2>/dev/null || echo "UNKNOWN"
}

# Backup important files before modifications
backup_files() {
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "$backup_path"
    
    # Backup existing installation if present
    if [ -f "$FINAL_SCRIPT" ]; then
        cp "$FINAL_SCRIPT" "${backup_path}/"
    fi
    
    # Backup service files if they exist
    if [ -d "/etc/systemd/system" ]; then
        cp /etc/systemd/system/hhf-* "${backup_path}/" 2>/dev/null || true
    fi
    
    print_status "Created backup at ${backup_path}"
}

# Restore from backup
restore_from_backup() {
    local latest_backup=$(ls -t "${BACKUP_DIR}" | head -1)
    if [ -n "$latest_backup" ]; then
        print_warning "Attempting to restore from backup..."
        cp "${BACKUP_DIR}/${latest_backup}"/* / 2>/dev/null || true
        systemctl daemon-reload
        print_success "Restoration completed"
    else
        print_error "No backup found to restore from"
    fi
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Create temporary directory with error handling
create_temp_dir() {
    print_status "Creating temporary directory..."
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR" || {
            print_error "Failed to remove existing temporary directory"
            return 1
        }
    fi
    mkdir -p "$TEMP_DIR" || {
        print_error "Failed to create temporary directory"
        return 1
    }
    chmod 755 "$TEMP_DIR"
}

# Enhanced cleanup function
cleanup() {
    local exit_code=$?
    local current_state=$(get_state)
    
    print_status "Performing cleanup..."
    
    # Remove temporary directory if it exists
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Handle different exit scenarios
    if [ $exit_code -ne 0 ]; then
        print_error "Script execution failed or was interrupted"
        case "$current_state" in
            "DOWNLOADING")
                print_warning "Failed during download phase"
                print_status "You can retry the installation"
                ;;
            "INSTALLING")
                print_warning "Failed during installation phase"
                restore_from_backup
                ;;
            *)
                print_warning "Failed in unknown state: $current_state"
                ;;
        esac
        
        print_status "Check the log file at $LOG_FILE for details"
    else
        if [ "$current_state" = "COMPLETE" ]; then
            print_success "Installation completed successfully"
        fi
    fi
}

# Download and prepare script parts with recovery
download_parts() {
    update_state "DOWNLOADING"
    print_status "Downloading script components..."
    
    local retry_count=0
    local max_retries=3
    
    for part in "${SCRIPT_PARTS[@]}"; do
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
            print_status "Downloading $part (attempt $((retry_count + 1))/${max_retries})..."
            if curl -sSL "${REPO_BASE}/${part}" -o "${TEMP_DIR}/${part}"; then
                chmod +x "${TEMP_DIR}/${part}"
                sed -i 's/\r$//' "${TEMP_DIR}/${part}"
                print_success "Downloaded and prepared ${part}"
                break
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -eq $max_retries ]; then
                    print_error "Failed to download ${part} after ${max_retries} attempts"
                    return 1
                fi
                print_warning "Retrying download in 5 seconds..."
                sleep 5
            fi
        done
    done
    return 0
}

# Enhanced verification with detailed checks
verify_parts() {
    update_state "VERIFYING"
    print_status "Verifying script components..."
    
    for part in "${SCRIPT_PARTS[@]}"; do
        print_status "Verifying ${part}..."
        
        # Check file existence
        if [ ! -f "${TEMP_DIR}/${part}" ]; then
            print_error "Missing script part: ${part}"
            return 1
        fi
        
        # Check file size
        if [ ! -s "${TEMP_DIR}/${part}" ]; then
            print_error "Empty script part: ${part}"
            return 1
        fi
        
        # Check file permissions
        if [ ! -x "${TEMP_DIR}/${part}" ]; then
            print_error "Script part not executable: ${part}"
            chmod +x "${TEMP_DIR}/${part}" || return 1
        fi
        
        # Verify shell syntax
        if ! bash -n "${TEMP_DIR}/${part}"; then
            print_error "Invalid shell syntax in: ${part}"
            return 1
        fi
        
        print_success "Verified ${part}"
    done
    return 0
}

# Combine scripts with better error handling
combine_scripts() {
    update_state "INSTALLING"
    print_status "Combining script components..."
    
    # Backup existing installation
    backup_files
    
    # Create directory for final script
    mkdir -p "$(dirname "$FINAL_SCRIPT")" || {
        print_error "Failed to create directory for final script"
        return 1
    }
    
    # Create final script with header
    cat > "$FINAL_SCRIPT" << EOF || return 1
#!/bin/bash
# HHFTechnology Media Server Installation Script
# Generated: $(date)
# Version: 1.0.0

EOF
    
    # Append each part
    for part in "${SCRIPT_PARTS[@]}"; do
        print_status "Adding ${part} to final script..."
        if ! tail -n +2 "${TEMP_DIR}/${part}" >> "$FINAL_SCRIPT"; then
            print_error "Failed to append ${part} to final script"
            return 1
        fi
        echo "" >> "$FINAL_SCRIPT"
    done
    
    # Set permissions
    chmod +x "$FINAL_SCRIPT" || {
        print_error "Failed to set executable permissions for final script"
        return 1
    }
    
    print_success "Successfully combined all script parts"
    return 0
}

# Install dependencies with retries
install_dependencies() {
    update_state "DEPENDENCIES"
    print_status "Installing required dependencies..."
    
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if apt-get update && apt-get install -y curl wget; then
            print_success "Successfully installed dependencies"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -eq $max_retries ]; then
                print_error "Failed to install dependencies after ${max_retries} attempts"
                return 1
            fi
            print_warning "Retrying dependency installation in 5 seconds..."
            sleep 5
        fi
    done
}

# Main execution with recovery
main() {
    clear
    echo "HHFTechnology Media Server Installer"
    echo "===================================="
    echo ""
    
    # Initialize logging and state tracking
    init_state_tracking
    
    # Check if this is a recovery attempt
    local prev_state=$(get_state)
    if [ "$prev_state" != "INIT" ] && [ "$prev_state" != "COMPLETE" ]; then
        print_warning "Previous incomplete installation detected (State: $prev_state)"
        read -p "Would you like to resume the installation? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Resuming installation from state: $prev_state"
        else
            print_status "Starting fresh installation"
            update_state "INIT"
        fi
    fi
    
    # Check root and install dependencies
    check_root
    install_dependencies || exit 1
    
    # Create temporary directory
    create_temp_dir || exit 1
    
    # Download and verify script parts
    download_parts || exit 1
    verify_parts || exit 1
    
    # Combine scripts
    combine_scripts || exit 1
    
    # Mark installation as complete
    update_state "COMPLETE"
    
    print_success "Installation script has been created successfully!"
    print_success "Location: $FINAL_SCRIPT"
    echo ""
    print_status "To start the installation, run:"
    echo "    sudo $FINAL_SCRIPT"
    echo ""
    print_status "Installation log available at: $LOG_FILE"
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Run main function
main
