#!/bin/bash

# Lazy Docker - User Permissions Detection
# This script detects the appropriate UID/GID for the current system
# to ensure proper file permissions inside the Docker container

detect_user_permissions() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - use current user's UID/GID to avoid permission issues
        export USER_UID=$(id -u)
        export USER_GID=$(id -g)
        if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]]; then
            # If running with sudo, use the original user's UID/GID
            export USER_UID=$SUDO_UID
            export USER_GID=$SUDO_GID
        fi
        printf "[INFO] Linux detected - Using UID:GID %s:%s for permission compatibility\n" "$USER_UID" "$USER_GID"
    else
        # macOS/Windows - use default (Docker Desktop handles this automatically)
        export USER_UID=1000
        export USER_GID=1000
        printf "[INFO] macOS/Windows detected - Using default UID:GID (Docker Desktop handles permissions)\n"
    fi
}

# Export the function so it can be sourced by other scripts
export -f detect_user_permissions

# If script is run directly, just detect and show the permissions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_user_permissions
    printf "USER_UID=%s\n" "$USER_UID"
    printf "USER_GID=%s\n" "$USER_GID"
fi
