#!/bin/bash

# =============================================================================
# 🐳 DOCKER COMPOSE INSTALLATION SCRIPT
# =============================================================================
# This script installs Docker Compose on your system.
#
# Usage: sudo ./install-docker-compose.sh
# =============================================================================

set -e

echo "🐳 Installing Docker Compose..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker Compose is already installed
if command_exists docker-compose; then
    print_status "Docker Compose is already installed"
    docker-compose --version
    exit 0
fi

if docker compose version >/dev/null 2>&1; then
    print_status "Docker Compose plugin is already installed"
    docker compose version
    exit 0
fi

# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

print_status "Detected OS: $OS, Architecture: $ARCH"

# Download and install Docker Compose
print_status "Downloading Docker Compose..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

if [ "$OS" = "Linux" ]; then
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="aarch64"
    elif [ "$ARCH" = "armv7l" ]; then
        ARCH="armv7"
    else
        print_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-${OS}-${ARCH}"
else
    print_error "Unsupported operating system: $OS"
    exit 1
fi

print_status "Downloading from: $DOWNLOAD_URL"

# Download Docker Compose
sudo curl -L "$DOWNLOAD_URL" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
if command_exists docker-compose; then
    print_status "Docker Compose installed successfully!"
    docker-compose --version
else
    print_error "Failed to install Docker Compose"
    exit 1
fi

# Create symlink for docker compose plugin
print_status "Creating symlink for docker compose plugin..."
sudo ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose-plugin

print_status "Installation completed successfully!"
print_status "You can now use:"
print_status "  docker-compose --version"
print_status "  docker compose version"