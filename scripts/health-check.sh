#!/bin/bash

# Lazy Docker Health Check Script
# This script checks the health of the Lazy Docker environment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="lazyvim"

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

print_header() {
    printf "${BLUE}=== Lazy Docker Health Check ===${NC}\n"
    printf "\n"
}

print_separator() {
    printf "\n"
    printf -- "-----------------------------------\n"
    printf "\n"
}

# Main health check function
health_check() {
    print_header
    
    # Check Docker
    log_info "Checking Docker..."
    if docker info >/dev/null 2>&1; then
        log_success "Docker is running"
        DOCKER_VERSION=$(docker --version)
        printf "  Version: %s\n" "$DOCKER_VERSION"
    else
        log_error "Docker is not running or not installed"
        return 1
    fi
    
    print_separator
    
    # Check Docker Compose
    log_info "Checking Docker Compose..."
    if docker compose version >/dev/null 2>&1; then
        log_success "Docker Compose is available"
        COMPOSE_VERSION=$(docker compose version --short)
        printf "  Version: %s\n" "$COMPOSE_VERSION"
    else
        log_error "Docker Compose is not available"
        return 1
    fi
    
    print_separator
    
    # Check container status
    log_info "Checking container status..."
    CONTAINER_STATE=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing")
    
    if [ "$CONTAINER_STATE" = "missing" ]; then
        log_warning "Container does not exist"
        printf "  Use 'make build' to create it\n"
    elif [ "$CONTAINER_STATE" = "running" ]; then
        log_success "Container is running"
        
        # Check container health
        log_info "Checking container health..."
        CONTAINER_HEALTH=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "No health check")
        
        printf "  Status: %s\n" "$CONTAINER_STATE"
        printf "  Health: %s\n" "$CONTAINER_HEALTH"
        
        # Check if we can execute commands in the container
        if docker exec "$CONTAINER_NAME" echo "Container accessible" >/dev/null 2>&1; then
            log_success "Container is accessible"
        else
            log_warning "Container is not accessible"
        fi
    else
        log_warning "Container exists but is stopped ($CONTAINER_STATE)"
        printf "  Use 'make start' to start it\n"
    fi
    
    print_separator
    
    # Check volumes
    log_info "Checking volumes..."
    VOLUMES=$(docker volume ls | grep lazyvim || true)
    if [[ -n "$VOLUMES" ]]; then
        log_success "LazyVim volumes found:"
        printf "%s\n" "$VOLUMES" | sed 's/^/  /'
    else
        log_warning "No LazyVim volumes found"
    fi
    
    print_separator
    
    # Check dotfiles
    log_info "Checking dotfiles directory..."
    if [[ -d ".dotfiles" ]]; then
        log_success "Dotfiles directory exists"
        
        # Check individual dotfiles
        DOTFILES=(".dotfiles/.zshrc" ".dotfiles/.p10k.zsh" ".dotfiles/.config/nvim" ".dotfiles/.config/lazygit")
        for file in "${DOTFILES[@]}"; do
            if [[ -e "$file" ]]; then
                printf "  ✓ %s\n" "$file"
            else
                log_warning "Missing: $file"
            fi
        done
    else
        log_warning "Dotfiles directory does not exist"
        printf "  It will be created automatically when you build the environment\n"
    fi
    
    print_separator
    
    # Check VERSION file
    log_info "Checking version..."
    if [[ -f "VERSION" ]]; then
        VERSION=$(cat VERSION)
        log_success "Version file found: $VERSION"
    else
        log_error "VERSION file not found"
    fi
    
    print_separator
    
    # Final status
    log_info "Health check completed"
    
    FINAL_CONTAINER_STATE=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing")
    
    if [ "$FINAL_CONTAINER_STATE" = "running" ]; then
        log_success "Environment is ready to use!"
        printf "  Use 'make enter' to access the container\n"
    elif [ "$FINAL_CONTAINER_STATE" = "missing" ]; then
        log_info "Environment is not built"
        printf "  Use 'make build' to create the container\n"
    else
        log_info "Environment is not running"
        printf "  Use 'make start' to start the existing container\n"
    fi
}

# Run health check
health_check
