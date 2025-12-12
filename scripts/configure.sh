#!/bin/bash

# Lazy Docker - Enhanced Configuration Script v2.0
# Features:
# - Prevents duplicate directory mounts
# - Allows easy unmounting of directories from menu
# - Remembers user decisions (won't ask again for Documents if already configured)
# - Shows clear numbered list of mounted directories
# - Persistent preferences management

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

# Configuration file to store user preferences
CONFIG_FILE=".lazy-docker-config"

# Functions
log_info() {
    printf "${BLUE}ℹ️  ${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}✅ ${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}⚠️  ${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}❌ ${NC} %s\n" "$1"
}

log_step() {
    printf "${PURPLE}🔧 ${NC} %s\n" "$1"
}

print_header() {
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║           Lazy Docker - Smart Configuration Tool         ║${NC}\n"
    printf "${CYAN}║       Improved Directory & Timezone Manager v2.0           ║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

# Load user preferences
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Loaded previous configuration"
    else
        log_info "First time configuration"
    fi
}

# Save user preferences
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Lazy Docker Configuration - Auto-generated
# Last updated: $(date)
DOCUMENTS_DECISION="${DOCUMENTS_DECISION:-}"
PROJECTS_DECISION="${PROJECTS_DECISION:-}"
PROJECTS_PATH="${PROJECTS_PATH:-}"
LAST_TIMEZONE="${LAST_TIMEZONE:-}"
EOF
    log_info "Configuration saved to $CONFIG_FILE"
}

# Check if a directory mount already exists in docker-compose.yml
is_mount_exists() {
    local host_path="$1"
    
    # Normalize path for comparison (resolve $HOME, relative paths, etc.)
    local normalized_path="$host_path"
    if [[ "$host_path" =~ ^\$HOME ]]; then
        normalized_path="${host_path/\$HOME/$HOME}"
    fi
    
    # Check if mount exists in volumes section (non-commented line)
    local in_volumes_section=false
    while IFS= read -r line; do
        # Check if we're entering volumes section
        if [[ "$line" =~ ^[[:space:]]*volumes:[[:space:]]*$ ]]; then
            in_volumes_section=true
            continue
        fi
        
        # Check if we're leaving volumes section (next main section)
        if [[ "$in_volumes_section" == "true" ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z_-]+:[[:space:]]*$ ]] && [[ ! "$line" =~ volumes: ]]; then
            in_volumes_section=false
            continue
        fi
        
        # Check for mount within volumes section (non-commented)
        if [[ "$in_volumes_section" == "true" ]] && [[ ! "$line" =~ ^[[:space:]]*# ]] && \
           ([[ "$line" =~ "$host_path:" ]] || [[ "$line" =~ "$normalized_path:" ]]); then
            return 0  # Mount exists
        fi
    done < docker-compose.yml
    
    return 1  # Mount doesn't exist
}

# Get all current mounts in a structured way
get_current_mounts() {
    local show_numbers="${1:-false}"
    local counter=1
    local mounts_found=false
    local mounts_data=()
    
    printf "${CYAN}📁 Current Directory Mounts:${NC}\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Parse docker-compose.yml for volume mounts - look in volumes section
    local in_volumes_section=false
    while IFS= read -r line; do
        # Check if we're entering volumes section
        if [[ "$line" =~ ^[[:space:]]*volumes:[[:space:]]*$ ]]; then
            in_volumes_section=true
            continue
        fi
        
        # Check if we're leaving volumes section (next main section)
        if [[ "$in_volumes_section" == "true" ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z_-]+:[[:space:]]*$ ]] && [[ ! "$line" =~ volumes: ]]; then
            in_volumes_section=false
            continue
        fi
        
        # Process volume mounts only within volumes section
        if [[ "$in_volumes_section" == "true" ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):([^:]+)$ ]]; then
            local host_path="${BASH_REMATCH[1]}"
            local container_path="${BASH_REMATCH[2]}"
            
            # Skip ONLY system caches and configs, NOT user dotfiles
            if [[ "$container_path" =~ (/root/\.cache|/home/developer/\.cache|/tmp|cache|\.npm|\.pip|\.yarn) ]]; then
                continue
            fi
            
            # Expand environment variables for display
            local display_host_path="$host_path"
            if [[ "$host_path" =~ ^\$HOME ]]; then
                display_host_path="${host_path/\$HOME/$HOME}"
            fi
            
            # Store mount data for potential removal
            mounts_data+=("$host_path:$container_path")
            
            # Show numbered list if requested
            if [[ "$show_numbers" == "true" ]]; then
                printf "${YELLOW}%2d.${NC} " "$counter"
            else
                printf "    ${PURPLE}•${NC} "
            fi
            
            printf "${GREEN}Host:${NC} %s\n" "$display_host_path"
            printf "      ${CYAN}→${NC} Container: %s\n" "$container_path"
            
            # Check if directory or file exists
            if [[ -e "$display_host_path" ]]; then
                if [[ -d "$display_host_path" ]]; then
                    printf "      ${BLUE}Status:${NC} ${GREEN}✅ Directory Exists${NC}\n"
                elif [[ -f "$display_host_path" ]]; then
                    printf "      ${BLUE}Status:${NC} ${GREEN}✅ File Exists${NC}\n"
                else
                    printf "      ${BLUE}Status:${NC} ${GREEN}✅ Exists${NC}\n"
                fi
            else
                # For dotfiles that are created by the container, provide helpful info
                if [[ "$display_host_path" =~ \.dotfiles/\.(zshrc|p10k\.zsh)$ ]]; then
                    printf "      ${BLUE}Status:${NC} ${YELLOW}⚡ Will be auto-created on first run${NC}\n"
                elif [[ "$display_host_path" =~ \.dotfiles/\.config/(nvim|lazygit)$ ]]; then
                    printf "      ${BLUE}Status:${NC} ${YELLOW}⚡ Will be auto-created with configs${NC}\n"
                else
                    printf "      ${BLUE}Status:${NC} ${RED}❌ Missing${NC}\n"
                fi
            fi
            printf "\n"
            
            counter=$((counter + 1))
            mounts_found=true
        fi
    done < docker-compose.yml
    
    if [[ "$mounts_found" != "true" ]]; then
        printf "  ${GRAY}No custom directory mounts configured${NC}\n"
        printf "\n"
    fi
    
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Export mounts data for removal function
    export CURRENT_MOUNTS_DATA="${mounts_data[*]}"
    
    # Return 0 always to avoid script termination
    printf "%d\n" "$((counter - 1))" > /tmp/mount_count
    return 0
}

# Add a directory mount (prevents duplicates)
add_directory_mount() {
    local host_path="$1"
    local container_path="$2"
    
    # Check if mount already exists
    if is_mount_exists "$host_path"; then
        log_warning "Mount already exists: $host_path"
        return 1
    fi
    
    # Check if directory exists
    if [[ ! -d "$host_path" ]]; then
        log_error "Directory does not exist: $host_path"
        return 1
    fi
    
    # Add mount after the Documents line or at the appropriate place in volumes section
    if grep -q "Documents:" docker-compose.yml; then
        # Add after Documents line with proper formatting
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/\$HOME\/Documents:/a\\
      - $host_path:$container_path\\
" docker-compose.yml
        else
            sed -i "/\$HOME\/Documents:/a\\
      - $host_path:$container_path" docker-compose.yml
        fi
    else
        # Find the end of mount directories section and add there
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/# - \$HOME\/Documents:/a\\
      - $host_path:$container_path\\
" docker-compose.yml
        else
            sed -i "/# - \$HOME\/Documents:/a\\
      - $host_path:$container_path" docker-compose.yml
        fi
    fi
    
    log_success "Added mount: $host_path → $container_path"
    return 0
}

# Remove a directory mount by line number
remove_directory_mount() {
    local selection="$1"
    
    # Get current mounts data directly
    local mounts_data=()
    local counter=1
    
    # Parse docker-compose.yml for volume mounts - look in volumes section
    local in_volumes_section=false
    while IFS= read -r line; do
        # Check if we're entering volumes section
        if [[ "$line" =~ ^[[:space:]]*volumes:[[:space:]]*$ ]]; then
            in_volumes_section=true
            continue
        fi
        
        # Check if we're leaving volumes section (next main section)
        if [[ "$in_volumes_section" == "true" ]] && [[ "$line" =~ ^[[:space:]]*[a-zA-Z_-]+:[[:space:]]*$ ]] && [[ ! "$line" =~ volumes: ]]; then
            in_volumes_section=false
            continue
        fi
        
        # Process volume mounts only within volumes section
        if [[ "$in_volumes_section" == "true" ]] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^:]+):([^:]+)$ ]]; then
            local host_path="${BASH_REMATCH[1]}"
            local container_path="${BASH_REMATCH[2]}"
            
            # Skip ONLY system caches and configs, NOT user dotfiles
            if [[ "$container_path" =~ (/root/\.cache|/home/developer/\.cache|/tmp|cache|\.npm|\.pip|\.yarn) ]]; then
                continue
            fi
            
            # Store mount data for potential removal
            mounts_data+=("$host_path:$container_path")
            counter=$((counter + 1))
        fi
    done < docker-compose.yml
    
    if [[ ${#mounts_data[@]} -eq 0 ]]; then
        log_warning "No mounts available to remove"
        return 1
    fi
    
    # Validate selection
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt "${#mounts_data[@]}" ]]; then
        log_error "Invalid selection: $selection"
        return 1
    fi
    
    # Get the mount to remove (1-indexed to 0-indexed)
    local mount_to_remove="${mounts_data[$((selection - 1))]}"
    local host_path="${mount_to_remove%:*}"
    local container_path="${mount_to_remove#*:}"
    
    # Remove the mount line from docker-compose.yml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "\|^[[:space:]]*- $host_path:$container_path|d" docker-compose.yml
    else
        sed -i "\|^[[:space:]]*- $host_path:$container_path|d" docker-compose.yml
    fi
    
    log_success "Removed mount: $host_path → $container_path"
    return 0
}

# Configure timezone with memory
configure_timezone() {
    log_step "Configuring timezone..."
    
    # Detect system timezone
    local system_tz=""
    if command -v timedatectl >/dev/null 2>&1; then
        system_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || printf "")
    elif [[ -f /etc/timezone ]]; then
        system_tz=$(cat /etc/timezone 2>/dev/null || printf "")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        system_tz=$(ls -la /etc/localtime 2>/dev/null | sed 's/.*zoneinfo\///' || printf "")
    fi
    
    # Get current timezone from docker-compose.yml
    local current_tz=$(grep "TIMEZONE:" docker-compose.yml | awk '{print $2}' 2>/dev/null || printf "")
    local default_tz="${system_tz:-America/Mexico_City}"
    
    printf "🌍 Timezone Configuration:\n"
    printf "  Current in container: %s\n" "${current_tz:-"Not set"}"
    printf "  System timezone: %s\n" "${system_tz:-"Could not detect"}"
    printf "\n"
    
    # If we have a previous timezone decision and it matches current, skip
    if [[ -n "$LAST_TIMEZONE" ]] && [[ "$LAST_TIMEZONE" == "$current_tz" ]]; then
        log_info "Timezone already configured: $current_tz"
        return 0
    fi
    
    printf "Available timezone examples:\n"
    printf "  - America/New_York\n"
    printf "  - America/Los_Angeles\n"
    printf "  - America/Mexico_City\n"
    printf "  - Europe/London\n"
    printf "  - Europe/Madrid\n"
    printf "  - Asia/Tokyo\n"
    printf "\n"
    
    read -p "Enter timezone [$default_tz]: " timezone
    timezone=${timezone:-$default_tz}
    
    # Update docker-compose.yml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|TIMEZONE:.*|TIMEZONE: $timezone|" docker-compose.yml
    else
        sed -i "s|TIMEZONE:.*|TIMEZONE: $timezone|" docker-compose.yml
    fi
    
    LAST_TIMEZONE="$timezone"
    log_success "Timezone set to: $timezone"
}

# Configure Documents directory with smart state
configure_documents_directory() {
    local default_docs="$HOME/Documents"
    
    printf "📄 Documents Directory Configuration:\n"
    
    # Check if Documents directory exists
    if [[ ! -d "$default_docs" ]]; then
        log_warning "Documents directory not found: $default_docs"
        return 0
    fi
    
    # Check current state in docker-compose.yml
    local is_enabled=$(grep -v "^[[:space:]]*#" docker-compose.yml | grep -q "\$HOME/Documents:" && printf "yes" || printf "no")
    
    # If we have a previous decision and current state matches, skip asking
    if [[ -n "$DOCUMENTS_DECISION" ]]; then
        if [[ "$DOCUMENTS_DECISION" == "yes" ]] && [[ "$is_enabled" == "yes" ]]; then
            log_info "Documents directory already enabled: $default_docs"
            return 0
        elif [[ "$DOCUMENTS_DECISION" == "no" ]] && [[ "$is_enabled" == "no" ]]; then
            log_info "Documents directory already disabled (user preference)"
            return 0
        fi
    fi
    
    printf "  Path: %s\n" "$default_docs"
    printf "  Status: %s\n" "$([ "$is_enabled" == "yes" ] && printf "✅ Enabled" || printf "❌ Disabled")"
    printf "\n"
    
    local reply
    read -p "Mount Documents directory? [Y/n]: " reply
    
    case "$reply" in
        [nN][oO]|[nN])
            # Disable Documents mounting
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's|^[[:space:]]*- \$HOME/Documents:|      # - \$HOME/Documents:|' docker-compose.yml
            else
                sed -i 's|^[[:space:]]*- \$HOME/Documents:|      # - \$HOME/Documents:|' docker-compose.yml
            fi
            DOCUMENTS_DECISION="no"
            log_success "Documents directory mounting disabled"
            ;;
        *)
            # Enable Documents mounting
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's|^[[:space:]]*#[[:space:]]*- \$HOME/Documents:|      - \$HOME/Documents:|' docker-compose.yml
            else
                sed -i 's|^[[:space:]]*#[[:space:]]*- \$HOME/Documents:|      - \$HOME/Documents:|' docker-compose.yml
            fi
            DOCUMENTS_DECISION="yes"
            log_success "Documents directory mounting enabled"
            ;;
    esac
}

# Configure Projects directory with smart state
configure_projects_directory() {
    local default_projects=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        default_projects="$HOME/Developer"
    else
        default_projects="$HOME/Projects"
    fi
    
    printf "\n"
    printf "💻 Projects Directory Configuration:\n"
    
    # Get current Projects mount if exists
    local current_projects=$(grep -v "^[[:space:]]*#" docker-compose.yml | grep "Projects:/home/developer/Projects" | sed 's/.*- //' | sed 's/:.*//' || printf "")
    
    # If we have a previous decision and current state matches, skip asking
    if [[ -n "$PROJECTS_DECISION" ]]; then
        if [[ "$PROJECTS_DECISION" == "yes" ]] && [[ -n "$current_projects" ]]; then
            log_info "Projects directory already configured: $current_projects"
            return 0
        elif [[ "$PROJECTS_DECISION" == "no" ]] && [[ -z "$current_projects" ]]; then
            log_info "Projects directory already disabled (user preference)"
            return 0
        fi
    fi
    
    if [[ -n "$current_projects" ]]; then
        printf "  Current: %s\n" "$current_projects"
        printf "  Status: ✅ Enabled\n"
    else
        printf "  Default: %s\n" "$default_projects"
        printf "  Status: ❌ Not configured\n"
    fi
    printf "\n"
    
    local reply
    read -p "Mount Projects directory? [Y/n]: " reply
    
    case "$reply" in
        [nN][oO]|[nN])
            # Remove Projects mounting
            if [[ -n "$current_projects" ]]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "\|$current_projects.*Projects|d" docker-compose.yml
                else
                    sed -i "\|$current_projects.*Projects|d" docker-compose.yml
                fi
                log_success "Projects directory mounting removed"
            fi
            PROJECTS_DECISION="no"
            ;;
        *)
            local projects_path
            if [[ -n "$current_projects" ]]; then
                read -p "Projects directory path [$current_projects]: " projects_path
                projects_path=${projects_path:-$current_projects}
            else
                read -p "Projects directory path [$default_projects]: " projects_path
                projects_path=${projects_path:-$default_projects}
            fi
            
            if [[ -d "$projects_path" ]]; then
                # Remove existing Projects mount first
                if [[ -n "$current_projects" ]]; then
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "\|$current_projects.*Projects|d" docker-compose.yml
                    else
                        sed -i "\|$current_projects.*Projects|d" docker-compose.yml
                    fi
                fi
                
                # Add new Projects mount
                add_directory_mount "$projects_path" "/home/developer/Projects"
                
                PROJECTS_DECISION="yes"
                PROJECTS_PATH="$projects_path"
                log_success "Projects directory configured: $projects_path"
            else
                log_error "Directory does not exist: $projects_path"
                PROJECTS_DECISION="no"
            fi
            ;;
    esac
}

# Interactive menu for additional directories
configure_additional_directories() {
    printf "\n"
    printf "📂 Additional Directory Management:\n"
    printf "\n"
    
    while true; do
        printf "Choose an option:\n"
        printf "  ${GREEN}1.${NC} Add custom directory mount\n"
        printf "  ${YELLOW}2.${NC} Remove directory mount\n"
        printf "  ${BLUE}3.${NC} List current mounts\n"
        printf "  ${PURPLE}4.${NC} Add multiple directories at once\n"
        printf "  ${RED}5.${NC} Continue with configuration\n"
        printf "\n"
        
        read -p "Select option (1-5): " choice
        printf "\n"
        
        case "$choice" in
            1)
                read -p "Enter directory path to mount: " custom_dir
                if [[ -z "$custom_dir" ]]; then
                    log_warning "No directory specified"
                    continue
                fi
                
                # Expand ~ to $HOME
                if [[ "$custom_dir" =~ ^~ ]]; then
                    custom_dir="${custom_dir/#\~/$HOME}"
                fi
                
                if [[ ! -d "$custom_dir" ]]; then
                    log_error "Directory does not exist: $custom_dir"
                    continue
                fi
                
                local mount_name=$(basename "$custom_dir")
                read -p "Mount as [/home/developer/$mount_name]: " container_path
                container_path=${container_path:-"/home/developer/$mount_name"}
                
                if add_directory_mount "$custom_dir" "$container_path"; then
                    printf "\n"
                    log_success "Mount added successfully!"
                else
                    printf "\n"
                    log_error "Failed to add mount"
                fi
                ;;
            2)
                printf "Select directory mount to remove:\n"
                printf "\n"
                
                # Get and show numbered list
                get_current_mounts "true"
                local mount_count=$(cat /tmp/mount_count 2>/dev/null || printf "0")
                
                if [[ "$mount_count" -eq 0 ]]; then
                    printf "\n"
                    log_warning "No mounts available to remove"
                    continue
                fi
                
                printf "\n"
                read -p "Enter number to remove (or 'cancel'): " selection
                
                if [[ "$selection" == "cancel" ]] || [[ "$selection" == "c" ]]; then
                    log_info "Removal cancelled"
                    continue
                fi
                
                if remove_directory_mount "$selection"; then
                    printf "\n"
                    log_success "Mount removed successfully!"
                else
                    printf "\n"
                    log_error "Failed to remove mount"
                fi
                ;;
            3)
                get_current_mounts "false"
                ;;
            4)
                printf "Enter multiple directories (one per line, empty line to finish):\n"
                local dirs_to_add=()
                while true; do
                    read -p "Directory path: " dir_path
                    if [[ -z "$dir_path" ]]; then
                        break
                    fi
                    
                    # Expand ~ to $HOME
                    if [[ "$dir_path" =~ ^~ ]]; then
                        dir_path="${dir_path/#\~/$HOME}"
                    fi
                    
                    if [[ -d "$dir_path" ]]; then
                        dirs_to_add+=("$dir_path")
                        printf "  ${GREEN}✓${NC} Added to queue: $dir_path\n"
                    else
                        printf "  ${RED}✗${NC} Directory not found: $dir_path\n"
                    fi
                done
                
                if [[ ${#dirs_to_add[@]} -gt 0 ]]; then
                    printf "\nAdding ${#dirs_to_add[@]} directories...\n"
                    for dir in "${dirs_to_add[@]}"; do
                        local mount_name=$(basename "$dir")
                        local container_path="/home/developer/$mount_name"
                        if add_directory_mount "$dir" "$container_path"; then
                            log_success "Added: $dir → $container_path"
                        else
                            log_error "Failed to add: $dir"
                        fi
                    done
                    printf "\n"
                    log_success "Batch addition completed!"
                else
                    log_info "No directories were added"
                fi
                ;;
            5)
                break
                ;;
            *)
                log_warning "Invalid option. Please select 1-5."
                ;;
        esac
        printf "\n"
    done
}

# Main configuration flow
main() {
    print_header
    
    # Load previous configuration
    load_config
    
    log_step "Starting Lazy Docker configuration..."
    printf "\n"
    
    # Configure timezone
    configure_timezone
    printf "\n"
    
    # Configure directories
    log_step "Configuring directory mounts..."
    printf "\n"
    
    # Configure Documents directory (with memory)
    configure_documents_directory
    
    # Configure Projects directory (with memory)
    configure_projects_directory
    
    # Configure additional directories (interactive menu)
    configure_additional_directories
    
    # Save configuration
    save_config
    
    printf "\n"
    log_success "Configuration completed!"
    printf "\n"
    printf "Next steps:\n"
    printf "  ${CYAN}1.${NC} Run: ${GREEN}make build${NC} or ${GREEN}lazy build${NC} to rebuild the container\n"
    printf "  ${CYAN}2.${NC} Run: ${GREEN}make start${NC} or ${GREEN}lazy start${NC} to start LazyVim\n"
    printf "\n"
    printf "Your mounted directories will be available inside the container at:\n"
    get_current_mounts "false"
    printf "\n"
    
    # Clean up temp files
    rm -f /tmp/mount_count
    
    # Exit successfully
    exit 0
}

# Run main function only if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
