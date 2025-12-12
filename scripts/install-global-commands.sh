#!/bin/bash

# LazyVim Docker Global Commands Installer
# This script installs global commands to use LazyVim Docker from anywhere

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Get the absolute path of the lazy-docker directory
LAZYVIM_DOCKER_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Remove the /scripts part from the path
LAZYVIM_DOCKER_PATH="$(dirname "$LAZYVIM_DOCKER_PATH")"

log_info "LazyVim Docker Global Commands Installer"
printf "\n"
log_info "This will install global 'lazy' commands that you can use from anywhere:"
printf "  lazy start      -> make start\n"
printf "  lazy enter      -> make enter\n"
printf "  lazy stop       -> make stop\n"
printf "  lazy status     -> make status\n"
printf "  lazy build      -> make build\n"
printf "  lazy health     -> make health\n"
printf "  lazy update     -> make update\n"
printf "  lazy uninstall  -> Complete removal (same as curl method)\n"
printf "\n"

# Check if we're in the correct directory
if [[ ! -f "$LAZYVIM_DOCKER_PATH/Makefile" ]] || [[ ! -f "$LAZYVIM_DOCKER_PATH/docker-compose.yml" ]]; then
    log_error "LazyVim Docker project not found at: $LAZYVIM_DOCKER_PATH"
    exit 1
fi

# Function to install for Zsh
install_zsh() {
    local shell_config="$HOME/.zshrc"
    local marker_start="# LazyVim Docker Global Commands - START"
    local marker_end="# LazyVim Docker Global Commands - END"
    
    # Remove existing installation if present
    if grep -q "$marker_start" "$shell_config" 2>/dev/null; then
        log_info "Removing existing installation from Zsh..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/$marker_start/,/$marker_end/d" "$shell_config"
        else
            sed -i "/$marker_start/,/$marker_end/d" "$shell_config"
        fi
    fi
    
    log_info "Installing global commands for Zsh..."
    
    # Add the new configuration
    cat >> "$shell_config" << EOF

$marker_start
# LazyVim Docker - Global Commands
# Use 'lazy <command>' from anywhere to control LazyVim Docker
lazyvim_docker_path="$LAZYVIM_DOCKER_PATH"

# Colors for lazy command output
LAZY_RED='\033[0;31m'
LAZY_GREEN='\033[0;32m'
LAZY_YELLOW='\033[1;33m'
LAZY_BLUE='\033[0;34m'
LAZY_NC='\033[0m' # No Color

lazy() {
    if [[ \$# -eq 0 ]]; then
        printf "\${LAZY_BLUE}LazyVim Docker - Available Commands\${LAZY_NC}\n"
        printf "\n"
        printf "Usage: lazy <command>\n"
        printf "\n"
        printf "Available commands:\n"
        printf "  \${LAZY_GREEN}start\${LAZY_NC}       Start the container\n"
        printf "  \${LAZY_GREEN}enter\${LAZY_NC}       Enter the container (starts if stopped)\n"
        printf "  \${LAZY_GREEN}stop\${LAZY_NC}        Stop the container\n"
        printf "  \${LAZY_GREEN}status\${LAZY_NC}      Show container status\n"
        printf "  \${LAZY_GREEN}health\${LAZY_NC}      Run health diagnostics\n"
        printf "  \${LAZY_GREEN}build\${LAZY_NC}       Build/rebuild the container\n"
        printf "  \${LAZY_GREEN}restart\${LAZY_NC}     Restart the container\n"
        printf "  \${LAZY_GREEN}destroy\${LAZY_NC}     Destroy everything\n"
        printf "  \${LAZY_GREEN}clean\${LAZY_NC}       Clean up Docker resources\n"
        printf "  \${LAZY_GREEN}quick\${LAZY_NC}       Quick start (build + enter)\n"
        printf "  \${LAZY_GREEN}backup\${LAZY_NC}      Backup configurations\n"
        printf "  \${LAZY_GREEN}restore\${LAZY_NC}     Restore from backup\n"
        printf "  \${LAZY_GREEN}update\${LAZY_NC}      Update to latest version\n"
        printf "  \${LAZY_GREEN}version\${LAZY_NC}     Show version\n"
        printf "  \${LAZY_GREEN}timezone\${LAZY_NC}    Check timezone configuration\n"
        printf "  \${LAZY_GREEN}configure\${LAZY_NC}   Reconfigure directories and timezone\n"
        printf "  \${LAZY_GREEN}uninstall\${LAZY_NC}   Complete removal (same as curl method)\n"
        printf "\n"
        printf "\${LAZY_YELLOW}Examples:\${LAZY_NC}\n"
        printf "  \${LAZY_GREEN}lazy enter\${LAZY_NC}     # Enter LazyVim from anywhere\n"
        printf "  \${LAZY_GREEN}lazy build\${LAZY_NC}     # Build the environment\n"
        return 0
    fi
    
    local cmd="\$1"
    shift
    
    case "\$cmd" in
        start|enter|stop|status|health|build|restart|destroy|clean|quick|backup|restore|update|version|timezone|configure)
            printf "🚀 Running: make %s %s\n" "\$cmd" "\$@"
            # Preserve TTY for interactive commands by not using subshell  
            local current_dir=\$(pwd)
            cd "\$lazyvim_docker_path"
            make "\$cmd" "\$@"
            cd "\$current_dir"
            ;;
        uninstall)
            printf "🗑️  Running complete uninstaller...\n"
            local current_dir=\$(pwd)
            cd "\$lazyvim_docker_path"
            ./scripts/uninstall.sh
            cd "\$current_dir"
            ;;
        *)
            printf "❌ Unknown command: %s\n" "\$cmd"
            printf "💡 Use 'lazy' to see available commands\n"
            return 1
            ;;
    esac
}

# Tab completion for lazy command (Zsh)
_lazy_zsh_completion() {
    local commands=(start enter stop status health build restart destroy clean quick backup restore update version timezone configure uninstall)
    _describe 'lazy commands' commands
}

compdef _lazy_zsh_completion lazy
$marker_end
EOF

    log_success "Zsh configuration updated!"
}

# Function to install for Bash
install_bash() {
    local shell_config="$HOME/.bashrc"
    local marker_start="# LazyVim Docker Global Commands - START"
    local marker_end="# LazyVim Docker Global Commands - END"
    
    # Remove existing installation if present
    if grep -q "$marker_start" "$shell_config" 2>/dev/null; then
        log_info "Removing existing installation from Bash..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/$marker_start/,/$marker_end/d" "$shell_config"
        else
            sed -i "/$marker_start/,/$marker_end/d" "$shell_config"
        fi
    fi
    
    log_info "Installing global commands for Bash..."
    
    # Add the new configuration
    cat >> "$shell_config" << EOF

$marker_start
# LazyVim Docker - Global Commands
# Use 'lazy <command>' from anywhere to control LazyVim Docker
lazyvim_docker_path="$LAZYVIM_DOCKER_PATH"

# Colors for lazy command output
LAZY_RED='\033[0;31m'
LAZY_GREEN='\033[0;32m'
LAZY_YELLOW='\033[1;33m'
LAZY_BLUE='\033[0;34m'
LAZY_NC='\033[0m' # No Color

lazy() {
    if [[ \$# -eq 0 ]]; then
        printf "\${LAZY_BLUE}LazyVim Docker - Available Commands\${LAZY_NC}\n"
        printf "\n"
        printf "Usage: lazy <command>\n"
        printf "\n"
        printf "Available commands:\n"
        printf "  \${LAZY_GREEN}start\${LAZY_NC}       Start the container\n"
        printf "  \${LAZY_GREEN}enter\${LAZY_NC}       Enter the container (starts if stopped)\n"
        printf "  \${LAZY_GREEN}stop\${LAZY_NC}        Stop the container\n"
        printf "  \${LAZY_GREEN}status\${LAZY_NC}      Show container status\n"
        printf "  \${LAZY_GREEN}health\${LAZY_NC}      Run health diagnostics\n"
        printf "  \${LAZY_GREEN}build\${LAZY_NC}       Build/rebuild the container\n"
        printf "  \${LAZY_GREEN}restart\${LAZY_NC}     Restart the container\n"
        printf "  \${LAZY_GREEN}destroy\${LAZY_NC}     Destroy everything\n"
        printf "  \${LAZY_GREEN}clean\${LAZY_NC}       Clean up Docker resources\n"
        printf "  \${LAZY_GREEN}quick\${LAZY_NC}       Quick start (build + enter)\n"
        printf "  \${LAZY_GREEN}backup\${LAZY_NC}      Backup configurations\n"
        printf "  \${LAZY_GREEN}restore\${LAZY_NC}     Restore from backup\n"
        printf "  \${LAZY_GREEN}update\${LAZY_NC}      Update to latest version\n"
        printf "  \${LAZY_GREEN}version\${LAZY_NC}     Show version\n"
        printf "  \${LAZY_GREEN}timezone\${LAZY_NC}    Check timezone configuration\n"
        printf "  \${LAZY_GREEN}configure\${LAZY_NC}   Reconfigure directories and timezone\n"
        printf "  \${LAZY_GREEN}uninstall\${LAZY_NC}   Complete removal (same as curl method)\n"
        printf "\n"
        printf "\${LAZY_YELLOW}Examples:\${LAZY_NC}\n"
        printf "  \${LAZY_GREEN}lazy enter\${LAZY_NC}     # Enter LazyVim from anywhere\n"
        printf "  \${LAZY_GREEN}lazy build\${LAZY_NC}     # Build the environment\n"
        return 0
    fi
    
    local cmd="\$1"
    shift
    
    case "\$cmd" in
        start|enter|stop|status|health|build|restart|destroy|clean|quick|backup|restore|update|version|timezone|configure)
            printf "🚀 Running: make %s %s\n" "\$cmd" "\$@"
            # Preserve TTY for interactive commands by not using subshell  
            local current_dir=\$(pwd)
            cd "\$lazyvim_docker_path"
            make "\$cmd" "\$@"
            cd "\$current_dir"
            ;;
        uninstall)
            printf "🗑️  Running complete uninstaller...\n"
            local current_dir=\$(pwd)
            cd "\$lazyvim_docker_path"
            ./scripts/uninstall.sh
            cd "\$current_dir"
            ;;
        *)
            printf "❌ Unknown command: %s\n" "\$cmd"
            printf "💡 Use 'lazy' to see available commands\n"
            return 1
            ;;
    esac
}

# Tab completion for lazy command (Bash)
_lazy_completion() {
    local cur="\${COMP_WORDS[COMP_CWORD]}"
    local commands="start enter stop status health build restart destroy clean quick backup restore update version timezone configure uninstall"
    COMPREPLY=(\$(compgen -W "\$commands" -- "\$cur"))
}

complete -F _lazy_completion lazy
$marker_end
EOF

    log_success "Bash configuration updated!"
}

# Main installation function
install_global_commands() {
    log_info "Installing global commands for both Bash and Zsh..."
    
    # Ensure shell config files exist
    touch "$HOME/.bashrc" "$HOME/.zshrc"
    
    # Install for both shells
    install_bash
    install_zsh
    
    printf "\n"
    log_success "✓ Global 'lazy' commands installed!"
    printf "\n"
    log_info "Commands installed for both Bash and Zsh:"
    printf "  • Bash: %s/.bashrc\n" "$HOME"
    printf "  • Zsh: %s/.zshrc\n" "$HOME"
    printf "\n"
    log_info "Usage:"
    printf "  lazy enter     # Enter LazyVim development environment\n"
    printf "\n"
    log_info "To activate:"
    printf "  • Restart your terminal, or\n"
    printf "  • Run: source ~/.bashrc   (for Bash)\n"
    printf "  • Run: source ~/.zshrc    (for Zsh)\n"
    printf "\n"
    
    # Detect current shell and provide specific activation command
    local current_shell=""
    if [[ -n "$ZSH_VERSION" ]]; then
        current_shell="zsh"
        printf "${GREEN}For your current Zsh session, run: source ~/.zshrc${NC}\n"
    elif [[ -n "$BASH_VERSION" ]]; then
        current_shell="bash"
        printf "${GREEN}For your current Bash session, run: source ~/.bashrc${NC}\n"
    elif [[ "$SHELL" == *"zsh"* ]]; then
        current_shell="zsh"
        printf "${GREEN}For your current Zsh session, run: source ~/.zshrc${NC}\n"
    else
        current_shell="bash"
        printf "${GREEN}For your current Bash session, run: source ~/.bashrc${NC}\n"
    fi
    
    printf "\n"
}

# Run the installation
install_global_commands
