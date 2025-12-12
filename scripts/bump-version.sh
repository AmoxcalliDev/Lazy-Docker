#!/bin/bash

# Version bump script for Lazy Docker
# Usage: ./bump-version.sh [patch|minor|major]

set -e

VERSION_FILE="VERSION"
BUMP_TYPE=${1:-patch}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    printf "${RED}Error: Invalid bump type. Use: patch, minor, or major${NC}\n"
    exit 1
fi

# Read current version
if [[ ! -f "$VERSION_FILE" ]]; then
    printf "${RED}Error: VERSION file not found${NC}\n"
    exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")
printf "${BLUE}Current version: $CURRENT_VERSION${NC}\n"

# Parse version components
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Bump version based on type
case $BUMP_TYPE in
    "patch")
        PATCH=$((PATCH + 1))
        ;;
    "minor")
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    "major")
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Write new version
echo "$NEW_VERSION" > "$VERSION_FILE"
printf "${GREEN}Version bumped to: $NEW_VERSION${NC}\n"

# Git commit if in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    printf "${YELLOW}Committing version bump...${NC}\n"
    git add "$VERSION_FILE"
    git commit -m "Bump version to $NEW_VERSION"
    git tag "v$NEW_VERSION"
    printf "${GREEN}Version committed and tagged${NC}\n"
fi
