#!/usr/bin/env bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (or with sudo)." >&2
    exit 1
fi


INSTALL_DIR="/usr/local/bin"
MAN_DIR="/usr/local/share/man/man1"

echo "Uninstalling fileman..."
rm -f "$INSTALL_DIR/fileman"

if [ -f "$MAN_DIR/fileman.1" ]; then
    echo "Removing man entry..."
    rm -f "$MAN_DIR/fileman.1"
    mandb || echo "Warning: 'mandb' command failed, man page index may not update immediately."
fi

echo "Uninstallation complete."
