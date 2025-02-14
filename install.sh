#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (or with sudo)." >&2
    exit 1
fi

INSTALL_DIR="/usr/local/bin"
MAN_DIR="/usr/share/man/man1"
mkdir -p $MAN_DIR
echo "Installing fileman..."
install -m 755 src/fileman.sh "$INSTALL_DIR/fileman"
echo "Adding man entry..."
install -m 644 man/fileman.1 "$MAN_DIR/fileman.1"
mandb || echo "Warning: 'mandb' command failed, man page may not be indexed immediately."
echo "Installation complete. You can now use 'fileman' from anywhere."
