#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
WESER_SOURCE="$SCRIPT_DIR/weser"
WESER_TARGET="$BIN_DIR/weser"

echo "Installing weser web server management tool..."

if [[ ! -f "$WESER_SOURCE" ]]; then
    echo "Error: weser script not found at $WESER_SOURCE"
    exit 1
fi

if [[ ! -x "$WESER_SOURCE" ]]; then
    echo "Error: weser script is not executable"
    exit 1
fi

if [[ ! -d "$BIN_DIR" ]]; then
    echo "Creating directory: $BIN_DIR"
    mkdir -p "$BIN_DIR"
fi

echo "Installing weser to $WESER_TARGET"
ln -sf "$WESER_SOURCE" "$WESER_TARGET"

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo ""
    echo "WARNING: $BIN_DIR is not in your PATH"
    echo "Add the following line to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "Or run this command and restart your shell:"
    echo "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo ""
fi

echo "Installation complete!"
echo ""
echo "Usage:"
echo "  weser lamp                  # Setup LAMP stack"
echo "  weser lemp                  # Setup LEMP stack" 
echo "  weser vhost -n domain.com   # Create virtual host"
echo "  weser ssl -d domain.com     # Generate SSL certificate"
echo ""
echo "For help: weser --help"