#!/bin/bash
# Installation script for claude-sync

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "═══════════════════════════════════════"
echo "  claude-sync Installation"
echo "═══════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}ERROR:${NC} Please do not run as root"
    echo "Run as your regular user: ./install.sh"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check dependencies
echo "Checking dependencies..."
DEPS=("gpg" "tar" "gzip" "sha256sum" "jq" "rsync")
MISSING=()

for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${YELLOW}WARNING:${NC} Missing dependencies: ${MISSING[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo apt update"
    echo "  sudo apt install ${MISSING[*]}"
    echo ""
    read -p "Continue anyway? [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Installation cancelled"
            exit 1
            ;;
    esac
fi

# Create installation directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Copy executable
echo "Installing claude-sync to $INSTALL_DIR..."
cp "$SCRIPT_DIR/bin/claude-sync" "$INSTALL_DIR/claude-sync"
chmod +x "$INSTALL_DIR/claude-sync"

# Create lib directory
LIB_INSTALL_DIR="$HOME/.local/lib/claude-sync"
mkdir -p "$LIB_INSTALL_DIR"

echo "Installing libraries to $LIB_INSTALL_DIR..."
cp -r "$SCRIPT_DIR/lib"/* "$LIB_INSTALL_DIR/"

# Update paths in installed executable
sed -i "s|LIB_DIR=.*|LIB_DIR=\"$LIB_INSTALL_DIR\"|" "$INSTALL_DIR/claude-sync"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo -e "${YELLOW}NOTE:${NC} $HOME/.local/bin is not in your PATH"
    echo ""
    echo "Add this to your ~/.bashrc:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""
    echo "Then run:"
    echo "  source ~/.bashrc"
    echo ""
fi

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "Verify installation:"
echo "  claude-sync --version"
echo ""
echo "Get started:"
echo "  claude-sync init"
echo "  claude-sync backup"
echo ""
echo "For help:"
echo "  claude-sync help"
echo ""
