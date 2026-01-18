#!/bin/bash
set -e

# Docker entrypoint script for GalOS development environment
# This script handles permission fixes for mounted volumes and user switching

# Default username
USERNAME=${USERNAME:-gal}
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# Function to fix permissions
fix_permissions() {
    echo "Fixing permissions for cargo directories..."

    # Fix cargo and rustup directories if they exist
    if [ -d "/usr/local/cargo" ]; then
        chown -R ${USERNAME}:${USERNAME} /usr/local/cargo 2>/dev/null || true
    fi

    if [ -d "/usr/local/rustup" ]; then
        chown -R ${USERNAME}:${USERNAME} /usr/local/rustup 2>/dev/null || true
    fi

    # Fix workspace directory if it exists
    if [ -d "/workspace" ]; then
        chown -R ${USERNAME}:${USERNAME} /workspace 2>/dev/null || true
    fi

    echo "Permissions fixed."
}

# Check if running as root
if [ "$(id -u)" = "0" ]; then
    # Running as root - fix permissions and switch to user
    fix_permissions

    # If no command specified, start a shell
    if [ $# -eq 0 ]; then
        exec gosu ${USERNAME} bash
    else
        # Execute the command as the non-root user
        exec gosu ${USERNAME} "$@"
    fi
else
    # Already running as non-root user
    echo "Running as non-root user: $(whoami)"

    # If no command specified, start a shell
    if [ $# -eq 0 ]; then
        exec bash
    else
        # Execute the command directly
        exec "$@"
    fi
fi
