#!/bin/bash

# LazyVim Docker - Simple Remote Installation Script
# This version uses smart defaults and skips interactive configuration
# Perfect for automated installations or when interactive input fails

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/AmoxcalliDev/Lazy-Docker"
REPO_NAME="Lazy-Docker"
INSTALL_DIR="$HOME/.local/share/lazy-docker"
BIN_DIR="$HOME/.local/bin"
TEMP_DIR="/tmp/lazy-docker-install"
BRANCH="${LAZYVIM_BRANCH:-main}"

# Print functions
print_header() {
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║             LazyVim Docker - Simple Installer               ║${NC}\n"
    printf "${CYAN}║                 Smart Defaults, Zero Input                  ║${NC}\n"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system requirements
check_requirements() {
    print_step "Checking system requirements..."
    
    local missing_deps=()
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker && ! docker compose version >/dev/null 2>&1; then
        print_warning "Docker or Docker Compose not found."
        if ! docker compose version >/dev/null 2>&1; then
            missing_deps+=("docker")
        fi
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        printf "\n"
        print_info "Please install the missing dependencies and try again:"
        printf "\n"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            printf "  brew install %s\n" "${missing_deps[*]}"
        elif [[ "$OSTYPE" == "linux"* ]]; then
            printf "  # Ubuntu/Debian:\n"
            printf "  sudo apt-get update && sudo apt-get install -y %s\n" "${missing_deps[*]}"
            printf "\n"
            printf "  # CentOS/RHEL:\n"
            printf "  sudo yum install -y %s\n" "${missing_deps[*]}"
        fi
        printf "\n"
        exit 1
    fi
    
    print_success "All requirements satisfied!"
}

# Create installation directories
create_directories() {
    print_step "Creating installation directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$TEMP_DIR"
    
    print_success "Directories created successfully"
}

# Download repository
download_repository() {
    print_step "Downloading LazyVim Docker repository..."
    
    cd "$TEMP_DIR"
    
    if command_exists git; then
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$REPO_NAME" >/dev/null 2>&1
    else
        curl -fsSL "${REPO_URL}/archive/${BRANCH}.tar.gz" | tar -xz --strip-components=1 -C "$REPO_NAME" 2>/dev/null
    fi
    
    print_success "Repository downloaded successfully"
}

# Install application
install_application() {
    print_step "Installing LazyVim Docker..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    fi
    
    cp -r "$TEMP_DIR/$REPO_NAME" "$INSTALL_DIR"
    
    print_success "Application installed to $INSTALL_DIR"
}

# Setup PATH for local bin directory
setup_local_bin_path() {
    local shell_config="$1"
    local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
    
    # Create config file if it doesn't exist
    touch "$shell_config"
    
    # Add to PATH if not already there
    if ! grep -q "$HOME/.local/bin" "$shell_config" 2>/dev/null; then
        printf "\n" >> "$shell_config"
        printf "# LazyVim Docker - Add local bin to PATH\n" >> "$shell_config"
        printf "%s\n" "$path_line" >> "$shell_config"
        print_info "Added $HOME/.local/bin to PATH in $shell_config"
    fi
}

# Create global commands
create_global_commands() {
    print_step "Installing global commands..."
    
    # Create bin directory if it doesn't exist
    mkdir -p "$BIN_DIR"
    
    # Run the installer script from the project
    cd "$INSTALL_DIR"
    chmod +x ./scripts/install-global-commands.sh
    if ./scripts/install-global-commands.sh; then
        print_success "Global commands installed successfully"
    else
        print_error "Failed to install global commands"
        exit 1
    fi
    
    # Ensure .local/bin is in PATH for both shells
    setup_local_bin_path "$HOME/.bashrc"
    setup_local_bin_path "$HOME/.zshrc"
    
    print_success "Global 'lazy' command is now available"
}

# Auto-configure with smart defaults
auto_configure() {
    print_step "Auto-configuring with smart defaults..."
    
    cd "$INSTALL_DIR"
    
    # Detect and set timezone
    local system_tz=""
    if command -v timedatectl >/dev/null 2>&1; then
        system_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
    elif [[ -f /etc/timezone ]]; then
        system_tz=$(cat /etc/timezone 2>/dev/null || echo "")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        system_tz=$(ls -la /etc/localtime 2>/dev/null | sed 's/.*zoneinfo\///' || echo "")
    fi
    
    local default_tz="${system_tz:-America/Mexico_City}"
    
    # Update timezone in docker-compose.yml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|TIMEZONE: .*|TIMEZONE: $default_tz|" docker-compose.yml
        sed -i '' "s|TZ=.*|TZ=$default_tz|" docker-compose.yml
    else
        sed -i "s|TIMEZONE: .*|TIMEZONE: $default_tz|" docker-compose.yml
        sed -i "s|TZ=.*|TZ=$default_tz|" docker-compose.yml
    fi
    
    print_success "Timezone configured: $default_tz"
    
    # Auto-configure directories
    local default_docs="$HOME/Documents"
    local default_projects=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        default_projects="$HOME/Developer"
    else
        default_projects="$HOME/Projects"
    fi
    
    # Configure Documents automatically if exists
    if [[ -d "$default_docs" ]]; then
        print_success "Documents directory will be mounted: $default_docs"
    else
        # Comment out the Documents line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's|^      - \$HOME/Documents:|      # - \$HOME/Documents:|' docker-compose.yml
        else
            sed -i 's|^      - \$HOME/Documents:|      # - \$HOME/Documents:|' docker-compose.yml
        fi
        print_info "Documents directory not found, mounting disabled"
    fi
    
    # Configure Projects automatically if exists
    if [[ -d "$default_projects" ]]; then
        # Add projects directory to docker-compose.yml
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/\$HOME\/Documents:/a\\
      - $default_projects:/home/developer/Projects" docker-compose.yml
        else
            sed -i "/\$HOME\/Documents:/a\\
      - $default_projects:/home/developer/Projects" docker-compose.yml
        fi
        print_success "Projects directory added: $default_projects"
    else
        print_info "Projects directory not found: $default_projects"
    fi
    
    print_success "Auto-configuration completed with smart defaults"
}

# Build environment
build_environment() {
    print_step "Building Docker environment..."
    
    cd "$INSTALL_DIR"
    
    print_info "This may take a few minutes..."
    if make build; then
        print_success "Docker environment built successfully"
    else
        print_warning "Docker build failed, but installation completed. You can run 'lazy build' later."
    fi
}

# Cleanup
cleanup() {
    print_step "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    print_success "Cleanup completed"
}

# Main installation process
main() {
    print_header
    
    print_info "Starting LazyVim Docker simple installation..."
    print_info "Installation directory: $INSTALL_DIR"
    print_info "Binary directory: $BIN_DIR"
    print_info "Using smart defaults (no interactive input required)"
    printf "\n"
    
    check_requirements
    create_directories
    download_repository
    install_application
    create_global_commands
    auto_configure
    build_environment
    cleanup
    
    printf "\n"
    print_success "🎉 LazyVim Docker installed successfully!"
    printf "\n"
    print_info "Configuration applied:"
    printf "  • Timezone: Auto-detected from system\n"
    printf "  • Documents: Auto-mounted if exists\n"
    printf "  • Projects: Auto-mounted if exists\n"
    printf "\n"
    print_info "Usage:"
    printf "  ${GREEN}lazy enter${NC}     # Enter LazyVim development environment\n"
    printf "  ${GREEN}lazy start${NC}     # Start the container\n"
    printf "  ${GREEN}lazy stop${NC}      # Stop the container\n"
    printf "  ${GREEN}lazy status${NC}    # Check container status\n"
    printf "  ${GREEN}lazy configure${NC} # Reconfigure directories and timezone\n"
    printf "  ${GREEN}lazy update${NC}    # Update to latest version\n"
    printf "  ${GREEN}lazy uninstall${NC} # Uninstall everything\n"
    printf "\n"
    print_info "To get started:"
    printf "  1. Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC} (or ~/.bashrc)\n"
    printf "  2. Run: ${GREEN}lazy enter${NC}\n"
    printf "\n"
    print_info "To customize configuration later:"
    printf "  Run: ${GREEN}lazy configure${NC}\n"
    printf "\n"
    print_info "Happy coding! 🚀"
}

# Run main function
main "$@"
