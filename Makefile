# Lazy Docker - Makefile
# Provides easy-to-use commands for managing the Lazy Docker environment

.PHONY: default build start enter stop destroy clean status update backup restore dev quick version bump-version restart
.PHONY: install-global uninstall install-remote configure

# Default target
.DEFAULT_GOAL := default

default: # Show all available commands (default when running 'make')
	@echo "$(BLUE)Lazy Docker Environment - Available Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Current version: $(VERSION)$(NC)"

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Read version from VERSION file
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0")
CONTAINER_NAME := lazyvim
COMPOSE_FILE := docker-compose.yml

# Detect user permissions for Linux compatibility
USER_UID := $(shell if [ "$(shell uname)" = "Linux" ]; then id -u; else echo "1000"; fi)
USER_GID := $(shell if [ "$(shell uname)" = "Linux" ]; then id -g; else echo "1000"; fi)

# Docker compose with environment variables for Linux permission compatibility
DOCKER_COMPOSE := USER_UID=$(USER_UID) USER_GID=$(USER_GID) docker compose

build: ## Build the Docker environment (clean build)
	@echo "$(BLUE)Building Lazy Docker environment v$(VERSION)...$(NC)"
	@./scripts/build.sh

start: ## Start the container (if already built)
	@echo "$(BLUE)Starting LazyVim container...$(NC)"
	@CONTAINER_STATE=$$(docker inspect $(CONTAINER_NAME) 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing"); \
	if [ "$$CONTAINER_STATE" = "missing" ]; then \
		echo "$(RED)Container not found. Please build first with 'make build'$(NC)"; \
		exit 1; \
	elif [ "$$CONTAINER_STATE" = "running" ]; then \
		echo "$(GREEN)Container is already running$(NC)"; \
	else \
		echo "$(YELLOW)Starting existing container...$(NC)"; \
		if docker compose start; then \
			echo "$(GREEN)Container started successfully$(NC)"; \
		else \
			echo "$(RED)Failed to start container$(NC)"; \
			exit 1; \
		fi \
	fi

enter: ## Enter the running container
	@echo "$(BLUE)Entering LazyVim container...$(NC)"
	@CONTAINER_STATE=$$(docker inspect $(CONTAINER_NAME) 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing"); \
	if [ "$$CONTAINER_STATE" = "missing" ]; then \
		echo "$(RED)Container not found. Please build first with 'make build'$(NC)"; \
		exit 1; \
	elif [ "$$CONTAINER_STATE" = "running" ]; then \
		docker exec -it $(CONTAINER_NAME) zsh; \
	else \
		echo "$(YELLOW)Container not running. Starting it first...$(NC)"; \
		if docker compose start; then \
			sleep 2; \
			docker exec -it $(CONTAINER_NAME) zsh; \
		else \
			echo "$(RED)Failed to start container$(NC)"; \
			exit 1; \
		fi \
	fi

stop: ## Stop the container (keeps volumes)
	@echo "$(YELLOW)Stopping LazyVim container...$(NC)"
	@docker compose stop
	@echo "$(GREEN)Container stopped$(NC)"

restart: ## Restart the container (stop and start)
	@echo "$(BLUE)Restarting LazyVim container...$(NC)"
	@docker compose restart
	@echo "$(GREEN)Container restarted$(NC)"

destroy: ## Destroy everything (container, images, and volumes)
	@echo "$(RED)Destroying LazyVim environment...$(NC)"
	@./scripts/destroy.sh

clean: ## Clean up unused Docker resources
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker system prune -f
	@docker volume prune -f
	@echo "$(GREEN)Cleanup completed$(NC)"

configure: ## Reconfigure directories and timezone
	@echo "$(BLUE)Reconfiguring Lazy Docker environment...$(NC)"
	@./scripts/configure.sh

health: ## Run comprehensive health diagnostics
	@echo "$(BLUE)Running LazyVim environment health check...$(NC)"
	@./scripts/health-check.sh

status: ## Show container status
	@echo "$(BLUE)Container Status:$(NC)"
	@CONTAINER_STATE=$$(docker inspect $(CONTAINER_NAME) 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing"); \
	if [ "$$CONTAINER_STATE" = "missing" ]; then \
		echo "$(RED)✗ Container does not exist$(NC)"; \
		echo "$(BLUE)Use 'make build' to create the container$(NC)"; \
	elif [ "$$CONTAINER_STATE" = "running" ]; then \
		echo "$(GREEN)✓ Container exists and is running$(NC)"; \
		docker compose ps; \
	else \
		echo "$(YELLOW)⚠ Container exists but is stopped ($$CONTAINER_STATE)$(NC)"; \
		echo "$(BLUE)Use 'make start' to start the container$(NC)"; \
		docker compose ps; \
	fi

update: ## Update to latest version and rebuild
	@./scripts/smart-update.sh

backup: ## Backup dotfiles and configuration
	@echo "$(BLUE)Creating backup of configuration...$(NC)"
	@mkdir -p backups
	@tar -czf backups/dotfiles-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz .dotfiles/
	@echo "$(GREEN)Backup created in backups/ directory$(NC)"

restore: ## Restore from backup (requires BACKUP_FILE variable)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Please specify BACKUP_FILE. Example: make restore BACKUP_FILE=backups/dotfiles-backup-20231201-120000.tar.gz$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restoring from $(BACKUP_FILE)...$(NC)"
	@tar -xzf $(BACKUP_FILE)
	@echo "$(GREEN)Restore completed$(NC)"

quick: ## Quick start - start container and enter (build only if needed)
	@echo "$(BLUE)Quick start...$(NC)"
	@CONTAINER_STATE=$$(docker inspect $(CONTAINER_NAME) 2>/dev/null | grep '"Status"' | cut -d'"' -f4 || echo "missing"); \
	if [ "$$CONTAINER_STATE" = "missing" ]; then \
		echo "$(YELLOW)Container not found. Building first...$(NC)"; \
		make build && make enter; \
	elif [ "$$CONTAINER_STATE" = "running" ]; then \
		make enter; \
	else \
		make start && make enter; \
	fi

version: ## Show current version
	@echo "$(GREEN)Current version: $(VERSION)$(NC)"

timezone: ## Check timezone configuration in container
	@echo "$(BLUE)Checking timezone configuration...$(NC)"
	@./scripts/check-timezone.sh

bump-version: ## Bump version (patch, minor, major)
	@if [ -z "$(TYPE)" ]; then \
		echo "$(RED)Please specify TYPE. Example: make bump-version TYPE=patch$(NC)"; \
		exit 1; \
	fi
	@./scripts/bump-version.sh $(TYPE)

install-global: ## Install global 'lazy' commands to use from anywhere
	@echo "$(BLUE)Installing Lazy Docker global commands...$(NC)"
	@./scripts/install-global-commands.sh

uninstall: ## Complete uninstall - removes everything (same as curl method)
	@echo "$(BLUE)Running complete Lazy Docker uninstall...$(NC)"
	@./scripts/uninstall.sh

install-remote:
	@echo "$(BLUE)Lazy Docker - Remote Installation$(NC)"
	@echo ""
	@echo "To install Lazy Docker remotely (recommended):"
	@echo "$(GREEN)curl -fsSL https://lazy-docker.amoxcalli.dev/install | bash$(NC)"
	@echo ""
	@echo "This will:"
	@echo "  • Download and install Lazy Docker to ~/.local/share/lazy-docker"
	@echo "  • Create global 'lazy' command"
	@echo "  • Build Docker environment with smart defaults"
	@echo "  • No repository cloning required - everything is automated"

remote-install: install-remote

test-scripts:
	@echo "$(BLUE)Testing installation scripts...$(NC)"
	@bash -n scripts/start.sh && echo "$(GREEN)✓ start.sh syntax OK$(NC)"
	@bash -n scripts/uninstall.sh && echo "$(GREEN)✓ uninstall.sh syntax OK$(NC)"  
	@bash -n scripts/smart-update.sh && echo "$(GREEN)✓ smart-update.sh syntax OK$(NC)"
	@echo "$(GREEN)All scripts passed syntax check!$(NC)"
