#!/bin/bash

# Lazy Docker Init Script
# This script starts and enters the Lazy Docker container
#
# RECOMMENDATION: Use 'make start' or 'make enter' instead of running this script directly
# The make commands provide better error handling and user feedback

set -e  # Exit on any error

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

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if container exists and its state
CONTAINER_STATE=$(docker inspect "$CONTAINER_NAME" 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || printf "missing")

if [ "$CONTAINER_STATE" = "missing" ]; then
    log_warning "Container not found. You may need to build it first."
    read -p "Do you want to build the environment? (y/N): " -n 1 -r
    printf "\n"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Building environment..."
        ./scripts/build.sh
        exit 0
    else
        log_error "Cannot proceed without building the environment first."
        log_info "Run 'make build' to build the environment."
        exit 1
    fi
elif [ "$CONTAINER_STATE" = "running" ]; then
    log_info "Container is already running"
else
    log_info "Container exists but is stopped. Starting it..."
    if docker compose start; then
        log_success "Container started successfully"
        sleep 2
    else
        log_error "Failed to start existing container"
        exit 1
    fi
fi

# Enter the container
log_info "Entering the LazyVim container..."
if docker exec -it "$CONTAINER_NAME" zsh; then
    log_success "Session ended"
else
    log_error "Failed to enter container"
    log_info "Container status:"
    docker compose ps
    exit 1
fi
