#!/bin/bash

# Lazy Docker - Remote Uninstall Script
# This script completely removes Lazy Docker from the system

set -e

# Colors for output using tput (more compatible)
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    RED=$(tput setaf 1 2>/dev/null || printf '')
    GREEN=$(tput setaf 2 2>/dev/null || printf '')
    YELLOW=$(tput setaf 3 2>/dev/null || printf '')
    BLUE=$(tput setaf 4 2>/dev/null || printf '')
    PURPLE=$(tput setaf 5 2>/dev/null || printf '')
    CYAN=$(tput setaf 6 2>/dev/null || printf '')
    NC=$(tput sgr0 2>/dev/null || printf '')
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    NC=''
fi

# Configuration
INSTALL_DIR="$HOME/.local/share/lazy-docker"
BIN_DIR="$HOME/.local/bin"

# Print functions
print_header() {
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║             Lazy Docker - Uninstaller                    ║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_step() {
    printf "${PURPLE}[STEP]${NC} %s\n" "$1"
}

# Smart terminal restart for clean environment
restart_terminal() {
    print_step "Setting up terminal cleanup..."
    
    # Detect current shell
    local current_shell=""
    if [ -n "$SHELL" ]; then
        case "$SHELL" in
            */zsh) current_shell="zsh" ;;
            */bash) current_shell="bash" ;;
            *) current_shell="bash" ;;
        esac
    else
        current_shell="bash"
    fi
    
    print_info "Detected shell: $current_shell"
    
    # Create a helper script for easy restart
    local helper_script="/tmp/lazyvim_cleanup_terminal.sh"
    cat > "$helper_script" << 'EOF'
#!/bin/bash
printf "🧹 Restarting terminal to complete Lazy Docker cleanup...\n"
printf "\n"
EOF
    printf "exec %s\n" "$current_shell" >> "$helper_script"
    chmod +x "$helper_script"
    
    printf "\n"
    print_warning "🧹 To complete cleanup and remove any traces:"
    printf "\n"
    printf "  ${GREEN}Option 1 (Easiest):${NC}\n"
    printf "    ${GREEN}%s${NC}\n" "$helper_script"
    printf "\n"
    printf "  ${GREEN}Option 2 (Manual):${NC}\n"
    printf "    ${GREEN}exec %s${NC}\n" "$current_shell"
    printf "\n"
    print_info "💡 Copy and paste the first command to clean your terminal"
    print_info "This ensures no traces of 'lazy' commands remain"
}

# Stop and remove Docker containers
cleanup_docker() {
    print_step "Cleaning up Docker containers and images..."
    
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        
        # Try to run make destroy first
        if command -v make >/dev/null 2>&1; then
            print_info "Running make destroy..."
            make destroy 2>/dev/null || {
                print_warning "make destroy failed, attempting manual cleanup..."
            }
        fi
        
        # Manual Docker cleanup
        if command -v docker >/dev/null 2>&1; then
            print_info "Removing Docker containers and images..."
            
            # Stop and remove containers
            docker stop lazyvim 2>/dev/null || true
            docker rm lazyvim 2>/dev/null || true
            
            # Remove images
            docker rmi lazy-docker_code-editor 2>/dev/null || true
            docker rmi $(docker images | grep lazyvim | awk '{print $3}') 2>/dev/null || true
            
            # Remove volumes
            docker volume rm lazy-docker_lazyvim-data 2>/dev/null || true
            docker volume rm $(docker volume ls | grep lazyvim | awk '{print $2}') 2>/dev/null || true
            
            print_success "Docker cleanup completed"
        else
            print_warning "Docker not found, skipping Docker cleanup"
        fi
    fi
}

# Remove installation directory
remove_installation() {
    print_step "Removing installation directory..."
    
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        print_success "Installation directory removed: $INSTALL_DIR"
    else
        print_warning "Installation directory not found: $INSTALL_DIR"
    fi
}

# Remove global commands from shell configurations
remove_shell_commands() {
    print_step "Removing global commands from shell configurations..."
    
    local configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile")
    local marker_start="# Lazy Docker Global Commands - START"
    local marker_end="# Lazy Docker Global Commands - END"
    local removed_any=false
    
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]] && grep -q "$marker_start" "$config" 2>/dev/null; then
            print_info "Removing commands from: $config"
            
            # Create backup
            cp "$config" "${config}.backup.$(date +%Y%m%d-%H%M%S)"
            
            # Remove the section between markers
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "/$marker_start/,/$marker_end/d" "$config"
            else
                sed -i "/$marker_start/,/$marker_end/d" "$config"
            fi
            
            removed_any=true
        fi
    done
    
    if [[ "$removed_any" == true ]]; then
        print_success "Global commands removed from shell configurations"
    else
        print_info "No global commands found in shell configurations"
    fi
}

# Remove global command
remove_global_command() {
    print_step "Removing global command..."
    
    if [ -f "$BIN_DIR/lazy" ]; then
        rm -f "$BIN_DIR/lazy"
        print_success "Global 'lazy' command removed"
    else
        print_warning "Global command not found: $BIN_DIR/lazy"
    fi
}

# Remove PATH modifications automatically
remove_path_modifications() {
    print_step "Removing PATH modifications..."
    
    local shell_configs=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile")
    local removed_any=false
    
    for config in "${shell_configs[@]}"; do
        if [ -f "$config" ]; then
            # Create backup
            cp "$config" "${config}.backup.$(date +%Y%m%d-%H%M%S)"
            
            # Remove Lazy Docker PATH modifications
            if grep -q "Lazy Docker" "$config" 2>/dev/null; then
                sed -i.tmp '/# Lazy Docker - Add local bin to PATH/d' "$config" 2>/dev/null || true
                sed -i.tmp '/export PATH=.*\.local\/bin.*PATH/d' "$config" 2>/dev/null || true
                rm -f "${config}.tmp"
                
                print_info "Cleaned PATH modifications from: $config"
                removed_any=true
            fi
        fi
    done
    
    if [[ "$removed_any" == true ]]; then
        print_success "PATH modifications removed"
    else
        print_info "No PATH modifications found"
    fi
}

# Confirm uninstallation
# Confirm uninstallation
confirm_uninstall() {
    printf "\n"
    print_warning "This will completely remove Lazy Docker from your system:"
    printf "  • Docker containers and images\n"
    printf "  • Installation directory (%s)\n" "$INSTALL_DIR"
    printf "  • Global 'lazy' command\n"
    printf "  • All data and configurations\n"
    printf "\n"
    
    # Try to read from terminal, fallback to stdin if needed
    printf "Are you sure you want to continue? [y/N]: "
    local response
    
    # Try multiple methods to read input
    if read -r response < /dev/tty 2>/dev/null; then
        # Successfully read from terminal
        :
    elif [[ -t 0 ]]; then
        # stdin is a terminal, try regular read
        read -r response
    else
        # Non-interactive mode or piped input
        if [[ "${LAZYVIM_FORCE_UNINSTALL:-}" == "true" ]]; then
            print_info "Non-interactive mode: proceeding with forced uninstall (LAZYVIM_FORCE_UNINSTALL=true)"
            response="y"
        else
            print_info "Non-interactive mode: uninstallation cancelled for safety"
            print_info "To force uninstall via pipe, set: LAZYVIM_FORCE_UNINSTALL=true"
            print_info ""
            print_info "Examples:"
            printf "  ${GREEN}LAZYVIM_FORCE_UNINSTALL=true curl -fsSL [URL] | bash${NC}\n"
            printf "  ${GREEN}curl -fsSL [URL] | LAZYVIM_FORCE_UNINSTALL=true bash${NC}\n"
            exit 0
        fi
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            print_info "Uninstallation cancelled"
            exit 0
            ;;
    esac
}

# Main uninstallation process
main() {
    print_header
    
    print_info "Lazy Docker Uninstaller"
    printf "\n"
    
    confirm_uninstall
    
    cleanup_docker
    remove_installation
    remove_global_command
    remove_shell_commands
    remove_path_modifications
    
    printf "\n"
    print_success "🗑️  Lazy Docker has been completely uninstalled!"
    printf "\n"
    print_info "What was removed:"
    print_info "  ✓ Docker containers and images"
    print_info "  ✓ Installation directory"
    print_info "  ✓ Global commands"
    printf "\n"
    print_info "Thank you for using Lazy Docker! 🚀"
    printf "\n"
    print_info "To reinstall later, run:"
    printf "  ${GREEN}curl -fsSL https://lazy-docker.amoxcalli.dev/install | bash${NC}\n"
    printf "\n"
    
    # Restart terminal to clean up environment
    restart_terminal
}

# Run main function
main "$@"
