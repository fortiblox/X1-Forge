#!/bin/bash
# X1-Forge Update Script
# Safely updates X1-Forge with automatic backup and rollback capability

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FORGE_REPO="fortiblox/X1-Forge"
INSTALL_DIR="/opt/x1-forge"
BACKUP_DIR="/opt/x1-forge/backups"
CONFIG_DIR="$HOME/.config/x1-forge"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get current version
get_current_version() {
    if [[ -f "$INSTALL_DIR/version" ]]; then
        cat "$INSTALL_DIR/version"
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub
get_latest_version() {
    curl -s "https://api.github.com/repos/$FORGE_REPO/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' || echo "unknown"
}

# Check for updates
check_updates() {
    local current=$(get_current_version)
    local latest=$(get_latest_version)

    echo ""
    echo "X1-Forge Update Check"
    echo "====================="
    echo "Current version: $current"
    echo "Latest version:  $latest"
    echo ""

    if [[ "$current" == "$latest" ]]; then
        log_success "You are running the latest version!"
        return 1
    else
        log_info "Update available: $current -> $latest"
        echo ""
        echo "Run 'x1-forge update' to upgrade"
        return 0
    fi
}

# Create backup before update
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"

    log_info "Creating backup at $backup_path..."

    mkdir -p "$backup_path"

    # Backup binary
    if [[ -f "$INSTALL_DIR/bin/x1-forge-validator" ]]; then
        cp "$INSTALL_DIR/bin/x1-forge-validator" "$backup_path/"
    fi

    # Backup config
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$backup_path/config"
    fi

    # Backup version
    if [[ -f "$INSTALL_DIR/version" ]]; then
        cp "$INSTALL_DIR/version" "$backup_path/"
    fi

    # Save backup reference
    echo "$backup_path" > "$INSTALL_DIR/last_backup"

    log_success "Backup created: $backup_path"
}

# Perform update
do_update() {
    local latest=$(get_latest_version)

    echo ""
    echo "X1-Forge Update"
    echo "==============="
    echo ""

    # Step 1: Backup
    echo "[1/6] Creating backup..."
    create_backup

    # Step 2: Download new version
    echo "[2/6] Downloading v$latest..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download release assets
    curl -sLO "https://github.com/$FORGE_REPO/releases/download/v$latest/x1-forge-validator"
    chmod +x x1-forge-validator

    # Step 3: Stop validator
    echo "[3/6] Stopping validator..."
    sudo systemctl stop x1-forge || true
    sleep 5

    # Step 4: Install new binary
    echo "[4/6] Installing new binary..."
    sudo cp x1-forge-validator "$INSTALL_DIR/bin/x1-forge-validator"
    echo "$latest" | sudo tee "$INSTALL_DIR/version" > /dev/null

    # Step 5: Start validator
    echo "[5/6] Starting validator..."
    sudo systemctl start x1-forge

    # Step 6: Health check
    echo "[6/6] Health check..."
    sleep 30

    if systemctl is-active --quiet x1-forge; then
        log_success "Update complete! Now running v$latest"
    else
        log_error "Validator failed to start. Rolling back..."
        do_rollback
        exit 1
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Rollback to previous version
do_rollback() {
    if [[ ! -f "$INSTALL_DIR/last_backup" ]]; then
        log_error "No backup found to rollback to"
        exit 1
    fi

    local backup_path=$(cat "$INSTALL_DIR/last_backup")

    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        exit 1
    fi

    log_info "Rolling back to backup: $backup_path"

    # Stop validator
    sudo systemctl stop x1-forge || true

    # Restore binary
    if [[ -f "$backup_path/x1-forge-validator" ]]; then
        sudo cp "$backup_path/x1-forge-validator" "$INSTALL_DIR/bin/"
    fi

    # Restore version
    if [[ -f "$backup_path/version" ]]; then
        sudo cp "$backup_path/version" "$INSTALL_DIR/"
    fi

    # Start validator
    sudo systemctl start x1-forge

    sleep 10

    if systemctl is-active --quiet x1-forge; then
        log_success "Rollback complete!"
    else
        log_error "Rollback failed. Manual intervention required."
        exit 1
    fi
}

# Main
case "${1:-}" in
    --check|-c)
        check_updates
        ;;
    --rollback|-r)
        do_rollback
        ;;
    ""|--update|-u)
        if check_updates; then
            echo ""
            read -p "Proceed with update? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                do_update
            fi
        fi
        ;;
    *)
        echo "X1-Forge Update Tool"
        echo ""
        echo "Usage: x1-forge update [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --check, -c     Check for available updates"
        echo "  --update, -u    Download and install updates (default)"
        echo "  --rollback, -r  Rollback to previous version"
        ;;
esac
