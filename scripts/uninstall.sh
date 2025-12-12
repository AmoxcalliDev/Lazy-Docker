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
    
    local configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile")
    local marker_start="# Lazy Docker Global Commands - START"
    local marker_end="# Lazy Docker Global Commands - END"
    local removed_any=false
    
    for config in "${configs[@]}"; do
        if [[ ! -f "$config" ]]; then
            continue
        fi
        
        # Create backup first
        cp "$config" "${config}.backup.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
        
        # Check and remove section between markers
        if grep -q "$marker_start" "$config" 2>/dev/null; then
            print_info "Removing lazy commands block from: $config"
            
            # Remove the section between markers
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "/$marker_start/,/$marker_end/d" "$config"
            else
                sed -i "/$marker_start/,/$marker_end/d" "$config"
            fi
            
            removed_any=true
        fi
        
        # Also remove any stray lines that might reference lazy function
        if grep -q "function lazy()" "$config" 2>/dev/null || grep -q "lazy()" "$config" 2>/dev/null; then
            print_info "Removing stray lazy function definitions from: $config"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/function lazy()/d' "$config"
                sed -i '' '/^lazy()/d' "$config"
            else
                sed -i '/function lazy()/d' "$config"
                sed -i '/^lazy()/d' "$config"
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
    
    # Remove binary/script file
    if [ -f "$BIN_DIR/lazy" ]; then
        rm -f "$BIN_DIR/lazy"
        print_success "Global 'lazy' command file removed from $BIN_DIR"
    else
        print_warning "Global command file not found: $BIN_DIR/lazy"
    fi
    
    # Try to unset the function in the current shell
    if declare -f lazy >/dev/null 2>&1; then
        unset -f lazy 2>/dev/null || true
        print_success "Unset 'lazy' function from current shell"
    fi
    
    # Also check if lazy is an alias
    if alias lazy >/dev/null 2>&1; then
        unalias lazy 2>/dev/null || true
        print_success "Removed 'lazy' alias from current shell"
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

# Cleanup temporary files and caches
cleanup_temp_files() {
    print_step "Cleaning up temporary files..."
    
    # Remove any temporary files created by lazy-docker
    rm -rf /tmp/lazy-docker-* 2>/dev/null || true
    rm -rf /tmp/lazyvim-* 2>/dev/null || true
    
    # Remove any config files left in home directory
    rm -f "$HOME/.lazy-docker-config" 2>/dev/null || true
    
    print_success "Temporary files cleaned"
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
    cleanup_temp_files
    
    printf "\n"
    print_success "🗑️  Lazy Docker has been completely uninstalled!"
    printf "\n"
    print_info "What was removed:"
    print_info "  ✓ Docker containers and images"
    print_info "  ✓ Installation directory ($INSTALL_DIR)"
    print_info "  ✓ Global 'lazy' command ($BIN_DIR/lazy)"
    print_info "  ✓ Shell configuration entries"
    print_info "  ✓ PATH modifications"
    printf "\n"
    
    # Important warning about shell reload
    print_warning "⚠️  IMPORTANT: Reload your shell to remove 'lazy' from memory"
    printf "\n"
    printf "  ${GREEN}Option 1 - Restart shell session:${NC}\n"
    printf "    ${GREEN}exec \$SHELL${NC}\n"
    printf "\n"
    printf "  ${GREEN}Option 2 - Restart zsh:${NC}\n"
    printf "    ${GREEN}exec zsh${NC}\n"
    printf "\n"
    printf "  ${GREEN}Option 3 - Source config again:${NC}\n"
    printf "    ${GREEN}source ~/.zshrc${NC}  or  ${GREEN}source ~/.bashrc${NC}\n"
    printf "\n"
    printf "  ${GREEN}Option 4 - Start new terminal:${NC}\n"
    printf "    Close this terminal and open a new one\n"
    printf "\n"
    
    print_info "Thank you for using Lazy Docker! 🚀"
    printf "\n"
    print_info "To reinstall later, run:"
    printf "  ${GREEN}curl -fsSL https://lazy-docker.amoxcalli.dev/install | bash${NC}\n"
    printf "\n"
}

# Run main function
main "$@"
