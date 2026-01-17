#!/bin/bash
# X1-Forge Installer & Configuration Tool
# Efficient Voting Validator for X1 Blockchain
#
# Usage:
#   curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
#   x1-forge-config          # After installation, use this for configuration
#   install.sh --config      # Or run installer with --config flag

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Configuration
FORGE_VERSION="1.0.0"
TACHYON_REPO="x1-labs/tachyon"
INSTALL_DIR="/opt/x1-forge"
CONFIG_DIR="$HOME/.config/x1-forge"
DATA_DIR="/mnt/x1-forge"
BIN_DIR="/usr/local/bin"
RPC_URL="https://rpc.mainnet.x1.xyz"
SETTINGS_FILE="$CONFIG_DIR/settings.conf"

# X1 Mainnet Configuration
ENTRYPOINTS=(
    "entrypoint0.mainnet.x1.xyz:8001"
    "entrypoint1.mainnet.x1.xyz:8001"
    "entrypoint2.mainnet.x1.xyz:8001"
)
KNOWN_VALIDATORS=(
    "7ufaUVtQKzGu5tpFtii9Cg8kR4jcpjQSXwsF3oVPSMZA"
    "5Rzytnub9yGTFHqSmauFLsAbdXFbehMwPBLiuEgKajUN"
    "4V2QkkWce8bwTzvvwPiNRNQ4W433ZsGQi9aWU12Q8uBF"
    "CkMwg4TM6jaSC5rJALQjvLc51XFY5pJ1H9f1Tmu5Qdxs"
    "7J5wJaH55ZYjCCmCMt7Gb3QL6FGFmjz5U8b6NcbzfoTy"
)

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_step() { echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  STEP $1: $2${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}\n"; }

# ═══════════════════════════════════════════════════════════════
# Settings Management
# ═══════════════════════════════════════════════════════════════

load_settings() {
    # Defaults
    AUTOSTART_ENABLED="true"
    AUTOUPDATE_ENABLED="false"
    VALIDATOR_NAME=""
    VALIDATOR_WEBSITE=""
    VALIDATOR_ICON=""

    if [[ -f "$SETTINGS_FILE" ]]; then
        source "$SETTINGS_FILE"
    fi
}

save_settings() {
    mkdir -p "$CONFIG_DIR"
    cat > "$SETTINGS_FILE" << EOF
# X1-Forge Settings
AUTOSTART_ENABLED="$AUTOSTART_ENABLED"
AUTOUPDATE_ENABLED="$AUTOUPDATE_ENABLED"
VALIDATOR_NAME="$VALIDATOR_NAME"
VALIDATOR_WEBSITE="$VALIDATOR_WEBSITE"
VALIDATOR_ICON="$VALIDATOR_ICON"
EOF
}

# ═══════════════════════════════════════════════════════════════
# Configuration Menu (Post-Install)
# ═══════════════════════════════════════════════════════════════

show_config_menu() {
    load_settings

    while true; do
        clear
        echo ""
        echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}   ${GREEN}${BOLD}X1-Forge Configuration${NC}                                    ${BLUE}║${NC}"
        echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Show current status
        if [[ -f "$CONFIG_DIR/identity.json" ]]; then
            IDENTITY_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/identity.json" 2>/dev/null || echo "invalid")
            echo -e "  Identity: ${GREEN}$IDENTITY_PUBKEY${NC}"
        else
            echo -e "  Identity: ${RED}Not configured${NC}"
        fi

        if [[ -f "$CONFIG_DIR/vote.json" ]]; then
            VOTE_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/vote.json" 2>/dev/null || echo "invalid")
            echo -e "  Vote Account: ${GREEN}$VOTE_PUBKEY${NC}"
        else
            echo -e "  Vote Account: ${RED}Not configured${NC}"
        fi

        if systemctl is-enabled x1-forge &>/dev/null; then
            echo -e "  Auto-start: ${GREEN}Enabled${NC}"
        else
            echo -e "  Auto-start: ${YELLOW}Disabled${NC}"
        fi

        if [[ "$AUTOUPDATE_ENABLED" == "true" ]]; then
            echo -e "  Auto-update: ${GREEN}Enabled${NC}"
        else
            echo -e "  Auto-update: ${YELLOW}Disabled${NC}"
        fi

        if systemctl is-active x1-forge &>/dev/null; then
            echo -e "  Service: ${GREEN}Running${NC}"
        else
            echo -e "  Service: ${YELLOW}Stopped${NC}"
        fi

        # Show validator name if set
        if [[ -n "$VALIDATOR_NAME" ]]; then
            echo -e "  Validator Name: ${GREEN}$VALIDATOR_NAME${NC}"
        else
            echo -e "  Validator Name: ${DIM}Not set${NC}"
        fi

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  1) Wallet Management"
        echo "  2) Validator Identity (name, website, icon)"
        echo "  3) Toggle Auto-Start on Boot"
        echo "  4) Toggle Auto-Update"
        echo "  5) Reconfigure Firewall"
        echo "  6) View Validator Info"
        echo "  7) Rebuild Validator Binary"
        echo -e "  8) ${RED}Uninstall X1-Forge${NC}"
        echo ""
        echo "  0) Exit"
        echo ""
        echo -e "${DIM}You are responsible for securing your private keys.${NC}"
        echo -e "${DIM}We do not store or manage your keys.${NC}"
        echo ""
        read -p "Select option: " config_choice

        case $config_choice in
            1) wallet_menu ;;
            2) validator_identity_menu ;;
            3) toggle_autostart ;;
            4) toggle_autoupdate ;;
            5) configure_firewall; read -p "Press Enter to continue..." ;;
            6) show_validator_info; read -p "Press Enter to continue..." ;;
            7) rebuild_binary; read -p "Press Enter to continue..." ;;
            8) uninstall_forge ;;
            0) exit 0 ;;
            *) ;;
        esac
    done
}

wallet_menu() {
    while true; do
        clear
        echo ""
        echo -e "${BOLD}Wallet Management${NC}"
        echo ""

        if [[ -f "$CONFIG_DIR/identity.json" ]]; then
            echo -e "  Current Identity: $(solana-keygen pubkey $CONFIG_DIR/identity.json 2>/dev/null)"
        fi
        if [[ -f "$CONFIG_DIR/vote.json" ]]; then
            echo -e "  Current Vote: $(solana-keygen pubkey $CONFIG_DIR/vote.json 2>/dev/null)"
        fi

        echo ""
        echo "  1) View wallet public keys"
        echo "  2) Check wallet balances"
        echo "  3) Import identity from file"
        echo "  4) Import vote account from file"
        echo "  5) Generate new identity (backup first!)"
        echo "  6) Generate new vote account (backup first!)"
        echo ""
        echo "  0) Back"
        echo ""
        read -p "Select option: " wallet_choice

        case $wallet_choice in
            1)
                echo ""
                echo "Identity: $(solana-keygen pubkey $CONFIG_DIR/identity.json 2>/dev/null || echo 'Not found')"
                echo "Vote: $(solana-keygen pubkey $CONFIG_DIR/vote.json 2>/dev/null || echo 'Not found')"
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                echo "Checking balances..."
                if [[ -f "$CONFIG_DIR/identity.json" ]]; then
                    BALANCE=$(solana balance "$CONFIG_DIR/identity.json" --url $RPC_URL 2>/dev/null || echo "Error")
                    echo "Identity balance: $BALANCE"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                read -p "Path to identity.json: " import_path
                import_path="${import_path/#\~/$HOME}"
                if [[ -f "$import_path" ]] && solana-keygen pubkey "$import_path" &>/dev/null; then
                    cp "$import_path" "$CONFIG_DIR/identity.json"
                    chmod 600 "$CONFIG_DIR/identity.json"
                    log_success "Identity imported"
                else
                    log_error "Invalid file"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                read -p "Path to vote.json: " import_path
                import_path="${import_path/#\~/$HOME}"
                if [[ -f "$import_path" ]] && solana-keygen pubkey "$import_path" &>/dev/null; then
                    cp "$import_path" "$CONFIG_DIR/vote.json"
                    chmod 600 "$CONFIG_DIR/vote.json"
                    log_success "Vote account imported"
                else
                    log_error "Invalid file"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                echo -e "${RED}WARNING: This will overwrite your current identity!${NC}"
                read -p "Are you sure? (type YES): " confirm
                if [[ "$confirm" == "YES" ]]; then
                    if [[ -f "$CONFIG_DIR/identity.json" ]]; then
                        mv "$CONFIG_DIR/identity.json" "$CONFIG_DIR/identity.json.backup.$(date +%s)"
                    fi
                    solana-keygen new -o "$CONFIG_DIR/identity.json" --no-passphrase --force
                    chmod 600 "$CONFIG_DIR/identity.json"
                    log_success "New identity generated"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                echo -e "${RED}WARNING: This will overwrite your current vote account!${NC}"
                read -p "Are you sure? (type YES): " confirm
                if [[ "$confirm" == "YES" ]]; then
                    if [[ -f "$CONFIG_DIR/vote.json" ]]; then
                        mv "$CONFIG_DIR/vote.json" "$CONFIG_DIR/vote.json.backup.$(date +%s)"
                    fi
                    solana-keygen new -o "$CONFIG_DIR/vote.json" --no-passphrase --force
                    chmod 600 "$CONFIG_DIR/vote.json"
                    log_success "New vote account generated"
                    echo "Note: You'll need to create this on-chain with:"
                    echo "  solana create-vote-account ~/.config/x1-forge/vote.json ~/.config/x1-forge/identity.json <WITHDRAWER> --url $RPC_URL"
                fi
                read -p "Press Enter to continue..."
                ;;
            0) return ;;
        esac
    done
}

validator_identity_menu() {
    load_settings

    while true; do
        clear
        echo ""
        echo -e "${BOLD}Validator Identity & Branding${NC}"
        echo ""
        echo "Set your validator's public identity on the X1 network."
        echo "This information appears in explorer and staking interfaces."
        echo ""

        echo -e "  Current Name:    ${VALIDATOR_NAME:-${DIM}Not set${NC}}"
        echo -e "  Current Website: ${VALIDATOR_WEBSITE:-${DIM}Not set${NC}}"
        echo -e "  Current Icon:    ${VALIDATOR_ICON:-${DIM}Not set${NC}}"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  1) Set Validator Name"
        echo "  2) Set Website URL"
        echo "  3) Set Icon/Image URL"
        echo "  4) Publish to Network"
        echo "  5) View Current On-Chain Info"
        echo ""
        echo "  0) Back"
        echo ""
        read -p "Select option: " id_choice

        case $id_choice in
            1)
                echo ""
                echo "Enter your validator name (e.g., 'MyValidator', 'Cool Staking Co'):"
                read -p "> " new_name
                if [[ -n "$new_name" ]]; then
                    VALIDATOR_NAME="$new_name"
                    save_settings
                    log_success "Name set to: $VALIDATOR_NAME"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                echo "Enter your website URL (e.g., 'https://myvalidator.com'):"
                read -p "> " new_website
                if [[ -n "$new_website" ]]; then
                    VALIDATOR_WEBSITE="$new_website"
                    save_settings
                    log_success "Website set to: $VALIDATOR_WEBSITE"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                echo "Enter your icon/image URL (must be publicly accessible .jpg, .png, or .gif)"
                echo ""
                echo -e "${DIM}Examples:${NC}"
                echo "  - https://pbs.twimg.com/profile_images/xxxxx/image.jpg"
                echo "  - https://i.imgur.com/xxxxx.png"
                echo "  - https://yoursite.com/validator-logo.png"
                echo ""
                echo -e "${YELLOW}Tip: Upload to Twitter/X, Imgur, or your own server${NC}"
                echo ""
                read -p "> " new_icon
                if [[ -n "$new_icon" ]]; then
                    VALIDATOR_ICON="$new_icon"
                    save_settings
                    log_success "Icon set to: $VALIDATOR_ICON"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                publish_validator_info
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                echo "Fetching on-chain validator info..."
                if [[ -f "$CONFIG_DIR/identity.json" ]]; then
                    solana validator-info get --keypair "$CONFIG_DIR/identity.json" --url $RPC_URL 2>/dev/null || echo "No info published yet"
                else
                    echo "Identity keypair not found"
                fi
                read -p "Press Enter to continue..."
                ;;
            0) return ;;
        esac
    done
}

publish_validator_info() {
    load_settings

    echo ""
    if [[ -z "$VALIDATOR_NAME" ]]; then
        log_error "Validator name is required. Set it first."
        return
    fi

    if [[ ! -f "$CONFIG_DIR/identity.json" ]]; then
        log_error "Identity keypair not found"
        return
    fi

    echo "Publishing validator info to the network..."
    echo ""
    echo "  Name:    $VALIDATOR_NAME"
    echo "  Website: ${VALIDATOR_WEBSITE:-Not set}"
    echo "  Icon:    ${VALIDATOR_ICON:-Not set}"
    echo ""

    # Build command
    CMD="solana validator-info publish \"$VALIDATOR_NAME\""
    CMD="$CMD --keypair \"$CONFIG_DIR/identity.json\""
    CMD="$CMD --url $RPC_URL"

    if [[ -n "$VALIDATOR_WEBSITE" ]]; then
        CMD="$CMD --website \"$VALIDATOR_WEBSITE\""
    fi

    if [[ -n "$VALIDATOR_ICON" ]]; then
        CMD="$CMD --icon-url \"$VALIDATOR_ICON\""
    fi

    echo "Running: $CMD"
    echo ""

    if eval $CMD; then
        log_success "Validator info published successfully!"
    else
        log_error "Failed to publish. Make sure your identity has enough XNT for the transaction."
    fi
}

toggle_autostart() {
    if systemctl is-enabled x1-forge &>/dev/null; then
        sudo systemctl disable x1-forge
        log_success "Auto-start disabled"
    else
        sudo systemctl enable x1-forge
        log_success "Auto-start enabled"
    fi
    sleep 1
}

toggle_autoupdate() {
    load_settings

    if [[ "$AUTOUPDATE_ENABLED" == "true" ]]; then
        AUTOUPDATE_ENABLED="false"
        # Remove cron job
        (crontab -l 2>/dev/null | grep -v "x1-forge-update") | crontab -
        log_success "Auto-update disabled"
    else
        AUTOUPDATE_ENABLED="true"
        # Add daily update check at 3 AM
        install_autoupdater
        log_success "Auto-update enabled (checks daily at 3 AM)"
    fi

    save_settings
    sleep 1
}

install_autoupdater() {
    # Create update script
    sudo tee "$INSTALL_DIR/bin/x1-forge-update" > /dev/null << 'UPDATER'
#!/bin/bash
# X1-Forge Auto-Updater

INSTALL_DIR="/opt/x1-forge"
TACHYON_REPO="x1-labs/tachyon"
LOG_FILE="/var/log/x1-forge-update.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting update check..."

# Check for updates by comparing git commits
cd /tmp
rm -rf tachyon-check
git clone --depth 1 https://github.com/$TACHYON_REPO.git tachyon-check 2>/dev/null

if [[ -d tachyon-check ]]; then
    NEW_COMMIT=$(cd tachyon-check && git rev-parse HEAD)
    CURRENT_COMMIT=$(cat "$INSTALL_DIR/commit" 2>/dev/null || echo "none")

    if [[ "$NEW_COMMIT" != "$CURRENT_COMMIT" ]]; then
        log "Update available: $CURRENT_COMMIT -> $NEW_COMMIT"

        # Build new version
        cd tachyon-check
        export RUSTFLAGS="-C target-cpu=native"
        if cargo build --release -p tachyon-validator >> "$LOG_FILE" 2>&1; then
            # Stop service
            systemctl stop x1-forge 2>/dev/null

            # Backup and install
            cp "$INSTALL_DIR/bin/x1-forge" "$INSTALL_DIR/bin/x1-forge.backup" 2>/dev/null
            cp target/release/tachyon-validator "$INSTALL_DIR/bin/x1-forge"
            chmod +x "$INSTALL_DIR/bin/x1-forge"
            echo "$NEW_COMMIT" > "$INSTALL_DIR/commit"

            # Restart service
            systemctl start x1-forge 2>/dev/null

            log "Update completed successfully"
        else
            log "Build failed, keeping current version"
        fi
    else
        log "Already up to date"
    fi

    rm -rf /tmp/tachyon-check
fi
UPDATER
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge-update"

    # Add to cron (daily at 3 AM)
    (crontab -l 2>/dev/null | grep -v "x1-forge-update"; echo "0 3 * * * $INSTALL_DIR/bin/x1-forge-update") | crontab -
}

show_validator_info() {
    echo ""
    echo -e "${BOLD}Validator Information${NC}"
    echo ""

    if [[ -f "$CONFIG_DIR/identity.json" ]]; then
        IDENTITY=$(solana-keygen pubkey "$CONFIG_DIR/identity.json")
        echo "Identity: $IDENTITY"
        echo "Balance: $(solana balance $CONFIG_DIR/identity.json --url $RPC_URL 2>/dev/null || echo 'Error')"
    fi

    if [[ -f "$CONFIG_DIR/vote.json" ]]; then
        VOTE=$(solana-keygen pubkey "$CONFIG_DIR/vote.json")
        echo "Vote Account: $VOTE"
        echo ""
        echo "Vote Account Details:"
        solana vote-account "$CONFIG_DIR/vote.json" --url $RPC_URL 2>/dev/null || echo "Not found on-chain"
    fi

    echo ""
    echo "Binary Version: $(cat $INSTALL_DIR/version 2>/dev/null || echo 'Unknown')"
    echo "Service Status: $(systemctl is-active x1-forge 2>/dev/null || echo 'Unknown')"
}

rebuild_binary() {
    echo ""
    log_info "Rebuilding X1-Forge from source..."
    echo "This will take 15-30 minutes."
    echo ""
    read -p "Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi

    # Stop service if running
    if systemctl is-active x1-forge &>/dev/null; then
        log_info "Stopping service..."
        sudo systemctl stop x1-forge
    fi

    cd /tmp
    rm -rf tachyon-build
    git clone --depth 1 https://github.com/$TACHYON_REPO.git tachyon-build
    cd tachyon-build

    export RUSTFLAGS="-C target-cpu=native"
    cargo build --release -p tachyon-validator

    sudo cp target/release/tachyon-validator "$INSTALL_DIR/bin/x1-forge"
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge"

    cd /
    rm -rf /tmp/tachyon-build

    log_success "Binary rebuilt"

    read -p "Start the service? (Y/n): " start_confirm
    if [[ ! "$start_confirm" =~ ^[Nn]$ ]]; then
        sudo systemctl start x1-forge
        log_success "Service started"
    fi
}

uninstall_forge() {
    clear
    echo ""
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║   UNINSTALL X1-FORGE                                          ║${NC}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will completely remove X1-Forge from your system.${NC}"
    echo ""
    echo "The following will be deleted:"
    echo "  - Service: x1-forge.service"
    echo "  - Binary: /opt/x1-forge/"
    echo "  - Data: /mnt/x1-forge/"
    echo "  - CLI tools: /usr/local/bin/x1-forge*"
    echo ""
    echo -e "${CYAN}Your keypair files will NOT be deleted:${NC}"
    echo "  ~/.config/x1-forge/identity.json"
    echo "  ~/.config/x1-forge/vote.json"
    echo ""
    echo -e "${RED}${BOLD}This action cannot be undone!${NC}"
    echo ""
    read -p "Type 'UNINSTALL' to confirm: " confirm

    if [[ "$confirm" != "UNINSTALL" ]]; then
        echo "Cancelled."
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    log_info "Stopping service..."
    sudo systemctl stop x1-forge 2>/dev/null || true
    sudo systemctl disable x1-forge 2>/dev/null || true

    log_info "Removing service file..."
    sudo rm -f /etc/systemd/system/x1-forge.service
    sudo systemctl daemon-reload

    log_info "Removing binary and data..."
    sudo rm -rf /opt/x1-forge
    sudo rm -rf /mnt/x1-forge

    log_info "Removing CLI tools..."
    sudo rm -f /usr/local/bin/x1-forge
    sudo rm -f /usr/local/bin/x1-forge-config

    log_info "Removing cron jobs..."
    (crontab -l 2>/dev/null | grep -v "x1-forge") | crontab - 2>/dev/null || true

    echo ""
    log_success "X1-Forge has been uninstalled."
    echo ""
    echo -e "${CYAN}Your keypair files were preserved at:${NC}"
    echo "  ~/.config/x1-forge/identity.json"
    echo "  ~/.config/x1-forge/vote.json"
    echo ""
    echo -e "${DIM}To remove them: rm -rf ~/.config/x1-forge${NC}"
    echo ""
    read -p "Press Enter to exit..."
    exit 0
}

# ═══════════════════════════════════════════════════════════════
# Installation Functions
# ═══════════════════════════════════════════════════════════════

print_banner() {
    clear
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   ${GREEN}${BOLD}X1-Forge${NC} - Efficient Voting Validator for X1              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   Version: ${FORGE_VERSION}                                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   ${YELLOW}Votes on blocks and earns staking rewards${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   ${YELLOW}Optimized for 64GB RAM (stripped MEV/Geyser/RPC)${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_overview() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}What This Script Will Do:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1. Check system requirements (RAM, CPU, disk space)"
    echo "  2. Install build tools, Rust, and Solana CLI"
    echo "  3. Generate or import your validator keypairs"
    echo "  4. Wait for you to fund your identity wallet"
    echo "  5. Create your vote account on-chain"
    echo "  6. Set validator identity (name, website, icon)"
    echo "  7. Build the validator from source (compiles Tachyon)"
    echo "  8. Configure firewall ports (8000-8020, 8899)"
    echo "  9. Optionally install as systemd service"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}What You'll Need:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  - sudo/root access"
    echo "  - Stable internet connection"
    echo "  - XNT tokens to fund your identity wallet (~0.5 XNT minimum)"
    echo "  - A secure wallet address for withdrawer (optional but recommended)"
    echo "  - 15-30 minutes for compilation"
    echo ""
    echo -e "${DIM}  Optional: Existing keypair files if migrating from another server${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Minimum Requirements:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  - 64 GB RAM (128 GB recommended)"
    echo "  - 8 CPU cores (16 recommended)"
    echo "  - 400 GB NVMe storage (1 TB recommended)"
    echo "  - 100 Mbps network (1 Gbps recommended)"
    echo "  - Ports 8000-8020, 8899 open"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}After Installation:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Run 'x1-forge-config' to:"
    echo "  - Manage wallets"
    echo "  - Toggle auto-start on boot"
    echo "  - Enable/disable auto-updates"
    echo "  - Reconfigure firewall"
    echo ""
}

check_requirements() {
    log_step "1/9" "Checking System Requirements"

    OS=$(uname -s)
    ARCH=$(uname -m)
    CPU_CORES=$(nproc)
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$((RAM_KB / 1024 / 1024))
    DISK_FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

    echo "Scanning your system..."
    echo ""

    local errors=0
    local warnings=0

    if [[ "$OS" == "Linux" ]]; then
        log_success "Operating System: Linux"
    else
        log_error "Operating System: $OS (Linux required)"
        errors=$((errors + 1))
    fi

    if [[ "$ARCH" == "x86_64" ]]; then
        log_success "Architecture: x86_64"
    else
        log_error "Architecture: $ARCH (x86_64 required)"
        errors=$((errors + 1))
    fi

    if [[ $CPU_CORES -ge 16 ]]; then
        log_success "CPU Cores: $CPU_CORES (recommended: 16+)"
    elif [[ $CPU_CORES -ge 8 ]]; then
        log_warn "CPU Cores: $CPU_CORES (minimum met, recommended: 16+)"
        warnings=$((warnings + 1))
    else
        log_error "CPU Cores: $CPU_CORES (minimum 8 required)"
        errors=$((errors + 1))
    fi

    if [[ $RAM_GB -ge 128 ]]; then
        log_success "RAM: ${RAM_GB}GB (recommended: 128GB+)"
    elif [[ $RAM_GB -ge 60 ]]; then
        log_warn "RAM: ${RAM_GB}GB (minimum met, recommended: 128GB+)"
        warnings=$((warnings + 1))
    else
        log_error "RAM: ${RAM_GB}GB (minimum 64GB required)"
        errors=$((errors + 1))
    fi

    if [[ $DISK_FREE_GB -ge 1000 ]]; then
        log_success "Disk Free: ${DISK_FREE_GB}GB (recommended: 1TB+)"
    elif [[ $DISK_FREE_GB -ge 400 ]]; then
        log_warn "Disk Free: ${DISK_FREE_GB}GB (minimum met, recommended: 1TB+)"
        warnings=$((warnings + 1))
    else
        log_error "Disk Free: ${DISK_FREE_GB}GB (minimum 400GB required)"
        errors=$((errors + 1))
    fi

    if command -v ss &>/dev/null; then
        if ss -tuln | grep -q ':8899 '; then
            log_warn "Port 8899 already in use"
            warnings=$((warnings + 1))
        else
            log_success "Port 8899: Available"
        fi
    fi

    echo ""
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}${BOLD}System does not meet minimum requirements ($errors issue(s))${NC}"
        echo ""
        echo -e "${YELLOW}Proceeding may result in poor performance, crashes, or inability to keep up with the network.${NC}"
        read -t 0.1 -n 10000 discard 2>/dev/null || true  # Clear input buffer
        read -p "Continue anyway? (y/N): " override_choice
        if [[ ! "$override_choice" =~ ^[Yy] ]]; then
            exit 1
        fi
        echo -e "${YELLOW}Proceeding with installation...${NC}"
    elif [[ $warnings -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}System meets minimum requirements with warnings.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        echo -e "${GREEN}${BOLD}All requirements met!${NC}"
    fi
}

install_dependencies() {
    log_step "2/9" "Installing Dependencies"

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq \
            build-essential pkg-config libssl-dev libudev-dev \
            libclang-dev protobuf-compiler curl wget git jq zstd bc
    elif command -v yum &>/dev/null; then
        sudo yum install -y -q \
            gcc gcc-c++ make pkgconfig openssl-devel systemd-devel \
            clang protobuf-compiler curl wget git jq zstd bc
    fi
    log_success "System dependencies installed"

    if command -v rustc &>/dev/null; then
        log_success "Rust already installed"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q
        source "$HOME/.cargo/env"
        log_success "Rust installed"
    fi

    if command -v solana &>/dev/null; then
        log_success "Solana CLI already installed"
    else
        sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)" 2>/dev/null
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        log_success "Solana CLI installed"
    fi

    solana config set --url $RPC_URL -q
}

backup_wallet() {
    local wallet_file="$1"
    local wallet_name="$2"

    if [[ -f "$wallet_file" ]]; then
        local backup_dir="$CONFIG_DIR/backups"
        local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
        local backup_file="$backup_dir/${wallet_name}_${timestamp}.json"

        mkdir -p "$backup_dir"
        cp "$wallet_file" "$backup_file"
        chmod 600 "$backup_file"

        log_success "Backed up $wallet_name to: $backup_file"
    fi
}

setup_wallets() {
    log_step "3/9" "Wallet Setup"

    mkdir -p "$CONFIG_DIR"
    IDENTITY_PATH="$CONFIG_DIR/identity.json"
    VOTE_PATH="$CONFIG_DIR/vote.json"

    echo "Your validator needs two keypairs:"
    echo "  1. ${BOLD}Identity${NC} - Your validator's unique identity"
    echo "  2. ${BOLD}Vote Account${NC} - Receives staking delegations"
    echo ""

    if [[ -f "$IDENTITY_PATH" ]] || [[ -f "$VOTE_PATH" ]]; then
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  WARNING: EXISTING WALLETS FOUND                              ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        [[ -f "$IDENTITY_PATH" ]] && echo -e "  Identity: ${CYAN}$(solana-keygen pubkey $IDENTITY_PATH 2>/dev/null)${NC}"
        [[ -f "$VOTE_PATH" ]] && echo -e "  Vote:     ${CYAN}$(solana-keygen pubkey $VOTE_PATH 2>/dev/null)${NC}"
        echo ""
        echo -e "${YELLOW}If you overwrite these wallets without a backup, they will be${NC}"
        echo -e "${YELLOW}LOST FOREVER. We cannot recover them for you.${NC}"
        echo ""
        echo "  1) ${YELLOW}Keep existing keypairs (recommended)${NC}"
        echo "  2) ${GREEN}Create NEW keypairs (will backup existing)${NC}"
        echo "  3) ${CYAN}Import keypairs (will backup existing)${NC}"
        echo ""
        read -p "Select [1-3]: " wallet_choice

        case $wallet_choice in
            1)
                if [[ ! -f "$IDENTITY_PATH" ]] || [[ ! -f "$VOTE_PATH" ]]; then
                    log_error "Both keypairs required"
                    setup_wallets
                    return
                fi
                log_success "Keeping existing keypairs"
                ;;
            2) create_new_wallets ;;
            3) import_existing_wallets ;;
        esac
    else
        echo "No existing keypairs found."
        echo ""
        echo "  1) ${GREEN}Create NEW keypairs${NC}"
        echo "  2) ${CYAN}Import EXISTING keypairs${NC}"
        echo ""
        read -p "Select [1-2]: " wallet_choice

        case $wallet_choice in
            1) create_new_wallets ;;
            2) import_existing_wallets ;;
        esac
    fi

    IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_PATH")

    echo ""
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  BACKUP YOUR KEYPAIRS NOW!                                    ║${NC}"
    echo -e "${RED}${BOLD}║  $IDENTITY_PATH${NC}"
    echo -e "${RED}${BOLD}║  $VOTE_PATH${NC}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    if [[ -d "$CONFIG_DIR/backups" ]]; then
        echo -e "${DIM}Previous backups stored in: $CONFIG_DIR/backups/${NC}"
    fi
    read -p "Press Enter after backing up..."
}

create_new_wallets() {
    # Backup existing wallets before overwriting
    if [[ -f "$CONFIG_DIR/identity.json" ]]; then
        log_info "Backing up existing identity..."
        backup_wallet "$CONFIG_DIR/identity.json" "identity"
    fi
    if [[ -f "$CONFIG_DIR/vote.json" ]]; then
        log_info "Backing up existing vote account..."
        backup_wallet "$CONFIG_DIR/vote.json" "vote"
    fi

    solana-keygen new -o "$CONFIG_DIR/identity.json" --no-passphrase --force -q
    chmod 600 "$CONFIG_DIR/identity.json"
    log_success "Identity created"

    solana-keygen new -o "$CONFIG_DIR/vote.json" --no-passphrase --force -q
    chmod 600 "$CONFIG_DIR/vote.json"
    log_success "Vote account created"
}

import_existing_wallets() {
    # Backup existing wallets before overwriting
    if [[ -f "$CONFIG_DIR/identity.json" ]]; then
        log_info "Backing up existing identity..."
        backup_wallet "$CONFIG_DIR/identity.json" "identity"
    fi
    if [[ -f "$CONFIG_DIR/vote.json" ]]; then
        log_info "Backing up existing vote account..."
        backup_wallet "$CONFIG_DIR/vote.json" "vote"
    fi

    echo ""
    echo "  1) Import from file paths"
    echo "  2) Paste private key bytes"
    read -p "Select [1-2]: " method

    if [[ "$method" == "1" ]]; then
        read -p "Path to identity.json: " id_path
        id_path="${id_path/#\~/$HOME}"
        cp "$id_path" "$CONFIG_DIR/identity.json"
        chmod 600 "$CONFIG_DIR/identity.json"

        read -p "Path to vote.json: " vote_path
        vote_path="${vote_path/#\~/$HOME}"
        cp "$vote_path" "$CONFIG_DIR/vote.json"
        chmod 600 "$CONFIG_DIR/vote.json"
    else
        echo "Paste identity key bytes:"
        read -r bytes
        echo "$bytes" > "$CONFIG_DIR/identity.json"
        chmod 600 "$CONFIG_DIR/identity.json"

        echo "Paste vote key bytes:"
        read -r bytes
        echo "$bytes" > "$CONFIG_DIR/vote.json"
        chmod 600 "$CONFIG_DIR/vote.json"
    fi
}

fund_identity() {
    log_step "4/9" "Fund Identity Wallet"

    IDENTITY_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/identity.json")
    BALANCE=$(solana balance "$CONFIG_DIR/identity.json" --url $RPC_URL 2>/dev/null | awk '{print $1}' || echo "0")

    echo "Current balance: ${BOLD}$BALANCE XNT${NC}"
    echo ""

    if (( $(echo "$BALANCE >= 0.5" | bc -l 2>/dev/null || echo 0) )); then
        log_success "Wallet funded!"
        return
    fi

    echo -e "Send XNT to: ${GREEN}${BOLD}$IDENTITY_PUBKEY${NC}"
    echo ""
    echo "Waiting for funds... (Ctrl+C to skip)"

    while true; do
        BALANCE=$(solana balance "$CONFIG_DIR/identity.json" --url $RPC_URL 2>/dev/null | awk '{print $1}' || echo "0")
        if (( $(echo "$BALANCE >= 0.1" | bc -l 2>/dev/null || echo 0) )); then
            log_success "Funds received: $BALANCE XNT"
            break
        fi
        echo -ne "\r  Balance: $BALANCE XNT - Waiting...  "
        sleep 30
    done
}

create_vote_account() {
    log_step "5/9" "Create Vote Account"

    IDENTITY_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/identity.json")
    VOTE_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/vote.json")

    if solana vote-account "$CONFIG_DIR/vote.json" --url $RPC_URL &>/dev/null; then
        log_success "Vote account exists"
        return
    fi

    echo "  1) Enter separate withdrawer (recommended)"
    echo "  2) Use identity as withdrawer"
    read -p "Select [1-2]: " choice

    if [[ "$choice" == "1" ]]; then
        read -p "Withdrawer public key: " WITHDRAWER
    else
        WITHDRAWER="$IDENTITY_PUBKEY"
    fi

    read -p "Commission % [10]: " COMMISSION
    COMMISSION=${COMMISSION:-10}

    solana create-vote-account "$CONFIG_DIR/vote.json" "$CONFIG_DIR/identity.json" "$WITHDRAWER" \
        --commission "$COMMISSION" --url $RPC_URL --keypair "$CONFIG_DIR/identity.json" || true
}

setup_validator_identity() {
    log_step "6/9" "Validator Identity (Optional)"

    echo "Set your validator's public identity on the X1 network."
    echo "This appears in explorers and staking interfaces."
    echo ""
    read -p "Configure now? (Y/n): " configure
    if [[ "$configure" =~ ^[Nn]$ ]]; then
        log_info "Skipped. Run 'x1-forge-config' later to set up."
        return
    fi

    echo ""
    echo "Enter your validator name (e.g., 'MyValidator', 'Cool Staking Co'):"
    read -p "> " VALIDATOR_NAME

    echo ""
    echo "Enter your website URL (optional, press Enter to skip):"
    read -p "> " VALIDATOR_WEBSITE

    echo ""
    echo "Enter your icon/image URL (optional, press Enter to skip)"
    echo -e "${DIM}Examples:${NC}"
    echo "  - https://pbs.twimg.com/profile_images/xxxxx/image.jpg"
    echo "  - https://i.imgur.com/xxxxx.png"
    echo "  - https://yoursite.com/logo.png"
    echo ""
    read -p "> " VALIDATOR_ICON

    save_settings

    if [[ -n "$VALIDATOR_NAME" ]]; then
        echo ""
        log_info "Publishing validator info..."

        CMD="solana validator-info publish \"$VALIDATOR_NAME\""
        CMD="$CMD --keypair \"$CONFIG_DIR/identity.json\""
        CMD="$CMD --url $RPC_URL"

        if [[ -n "$VALIDATOR_WEBSITE" ]]; then
            CMD="$CMD --website \"$VALIDATOR_WEBSITE\""
        fi

        if [[ -n "$VALIDATOR_ICON" ]]; then
            CMD="$CMD --icon-url \"$VALIDATOR_ICON\""
        fi

        if eval $CMD 2>/dev/null; then
            log_success "Validator info published!"
        else
            log_warn "Could not publish now. Run 'x1-forge-config' later to retry."
        fi
    fi
}

build_and_install() {
    log_step "7/9" "Build Validator"

    sudo mkdir -p "$INSTALL_DIR"/{bin,lib}
    sudo mkdir -p "$DATA_DIR"/ledger
    sudo chown -R "$USER:$USER" "$DATA_DIR" 2>/dev/null || true

    echo "Building from source (15-30 minutes)..."

    cd /tmp
    rm -rf tachyon-build
    git clone --depth 1 https://github.com/$TACHYON_REPO.git tachyon-build
    cd tachyon-build

    export RUSTFLAGS="-C target-cpu=native"
    cargo build --release -p tachyon-validator

    sudo cp target/release/tachyon-validator "$INSTALL_DIR/bin/x1-forge"
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge"
    echo "$FORGE_VERSION" | sudo tee "$INSTALL_DIR/version" > /dev/null
    git rev-parse HEAD | sudo tee "$INSTALL_DIR/commit" > /dev/null

    cd /
    rm -rf /tmp/tachyon-build

    log_success "Binary built"

    # Install CLI wrapper
    install_cli_wrapper

    # Apply kernel tuning
    apply_kernel_tuning
}

install_cli_wrapper() {
    sudo tee "$BIN_DIR/x1-forge" > /dev/null << 'WRAPPER'
#!/bin/bash
case "$1" in
    start)   sudo systemctl start x1-forge ;;
    stop)    sudo systemctl stop x1-forge ;;
    restart) sudo systemctl restart x1-forge ;;
    status)  sudo systemctl status x1-forge ;;
    logs)    journalctl -u x1-forge -f ;;
    catchup) solana catchup --our-localhost ;;
    health)  curl -s http://localhost:8899/health 2>/dev/null || echo "Not responding" ;;
    *)
        echo "X1-Forge - Voting Validator"
        echo "Commands: start|stop|restart|status|logs|catchup|health"
        ;;
esac
WRAPPER
    sudo chmod +x "$BIN_DIR/x1-forge"

    # Install config tool
    sudo tee "$BIN_DIR/x1-forge-config" > /dev/null << 'CONFIG'
#!/bin/bash
curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash -s -- --config
CONFIG
    sudo chmod +x "$BIN_DIR/x1-forge-config"
}

apply_kernel_tuning() {
    sudo tee /etc/sysctl.d/99-x1-forge.conf > /dev/null << 'EOF'
net.core.rmem_max=134217728
net.core.wmem_max=134217728
vm.max_map_count=2000000
vm.swappiness=10
fs.file-max=2097152
EOF
    sudo sysctl -p /etc/sysctl.d/99-x1-forge.conf 2>/dev/null || true

    sudo tee /etc/security/limits.d/99-x1-forge.conf > /dev/null << EOF
$USER soft nofile 1000000
$USER hard nofile 1000000
EOF
}

configure_firewall() {
    log_step "8/9" "Configure Firewall"

    echo "Required ports: 8000-8020 (UDP/TCP), 8899 (TCP)"
    echo ""

    if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        sudo ufw allow 8000:8020/tcp >/dev/null 2>&1
        sudo ufw allow 8000:8020/udp >/dev/null 2>&1
        sudo ufw allow 8899/tcp >/dev/null 2>&1
        log_success "UFW configured"
    elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
        sudo firewall-cmd --permanent --add-port=8000-8020/tcp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=8000-8020/udp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=8899/tcp >/dev/null 2>&1
        sudo firewall-cmd --reload >/dev/null 2>&1
        log_success "Firewalld configured"
    elif command -v iptables &>/dev/null; then
        sudo iptables -A INPUT -p tcp --dport 8000:8020 -j ACCEPT 2>/dev/null || true
        sudo iptables -A INPUT -p udp --dport 8000:8020 -j ACCEPT 2>/dev/null || true
        sudo iptables -A INPUT -p tcp --dport 8899 -j ACCEPT 2>/dev/null || true
        log_success "iptables configured"
    else
        log_warn "No firewall detected"
    fi

    echo -e "${DIM}Note: Configure cloud security groups separately if applicable.${NC}"
}

setup_service() {
    log_step "9/9" "Service Setup"

    echo "Install as systemd service?"
    echo "  - Enables 'x1-forge start/stop/restart' commands"
    echo "  - Optional auto-start on boot"
    echo ""
    read -p "Install service? (Y/n): " install_service
    if [[ "$install_service" =~ ^[Nn]$ ]]; then
        log_info "Skipping service installation"
        echo ""
        echo "To run manually:"
        echo "  $INSTALL_DIR/bin/x1-forge --identity ~/.config/x1-forge/identity.json ..."
        return
    fi

    IDENTITY_PATH="$CONFIG_DIR/identity.json"
    VOTE_PATH="$CONFIG_DIR/vote.json"

    sudo tee /etc/systemd/system/x1-forge.service > /dev/null << EOF
[Unit]
Description=X1-Forge Voting Validator
After=network.target

[Service]
Type=simple
User=$USER
Environment="RUST_LOG=solana_metrics=warn,info"
WorkingDirectory=$DATA_DIR

ExecStart=$INSTALL_DIR/bin/x1-forge \\
    --identity $IDENTITY_PATH \\
    --vote-account $VOTE_PATH \\
    --ledger $DATA_DIR/ledger \\
    --entrypoint entrypoint0.mainnet.x1.xyz:8001 \\
    --entrypoint entrypoint1.mainnet.x1.xyz:8001 \\
    --entrypoint entrypoint2.mainnet.x1.xyz:8001 \\
    --known-validator 7ufaUVtQKzGu5tpFtii9Cg8kR4jcpjQSXwsF3oVPSMZA \\
    --known-validator 5Rzytnub9yGTFHqSmauFLsAbdXFbehMwPBLiuEgKajUN \\
    --known-validator 4V2QkkWce8bwTzvvwPiNRNQ4W433ZsGQi9aWU12Q8uBF \\
    --known-validator CkMwg4TM6jaSC5rJALQjvLc51XFY5pJ1H9f1Tmu5Qdxs \\
    --known-validator 7J5wJaH55ZYjCCmCMt7Gb3QL6FGFmjz5U8b6NcbzfoTy \\
    --only-known-rpc \\
    --private-rpc \\
    --rpc-port 8899 \\
    --dynamic-port-range 8000-8020 \\
    --wal-recovery-mode skip_any_corrupted_record \\
    --limit-ledger-size 10000000 \\
    --log $DATA_DIR/forge.log

Restart=on-failure
RestartSec=30
LimitNOFILE=1000000
MemoryMax=60G

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    log_success "Service installed"

    echo ""
    read -p "Enable auto-start on boot? (Y/n): " autostart
    if [[ ! "$autostart" =~ ^[Nn]$ ]]; then
        sudo systemctl enable x1-forge
        AUTOSTART_ENABLED="true"
        log_success "Auto-start enabled"
    else
        AUTOSTART_ENABLED="false"
    fi

    echo ""
    read -p "Enable auto-updates? (y/N): " autoupdate
    if [[ "$autoupdate" =~ ^[Yy]$ ]]; then
        AUTOUPDATE_ENABLED="true"
        install_autoupdater
        log_success "Auto-updates enabled"
    else
        AUTOUPDATE_ENABLED="false"
    fi

    save_settings
}

print_completion() {
    clear
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   X1-Forge Installation Complete!                             ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}SAVE THIS INFORMATION:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Identity Pubkey: $(solana-keygen pubkey $CONFIG_DIR/identity.json 2>/dev/null)"
    echo "  Vote Pubkey:     $(solana-keygen pubkey $CONFIG_DIR/vote.json 2>/dev/null)"
    echo ""
    echo "  Identity File:   $CONFIG_DIR/identity.json"
    echo "  Vote File:       $CONFIG_DIR/vote.json"
    echo ""
    echo -e "${DIM}  Copy this information and store it somewhere safe.${NC}"
    echo -e "${DIM}  Back up your keypair files to secure offline storage!${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}COMMANDS (run from anywhere):${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  x1-forge start      Start the validator"
    echo "  x1-forge stop       Stop the validator"
    echo "  x1-forge logs       View live logs"
    echo "  x1-forge status     Check service status"
    echo "  x1-forge catchup    Check sync progress"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}CONFIGURATION:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  To change settings later, run: ${BOLD}x1-forge-config${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}UNINSTALL:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${DIM}  To completely remove X1-Forge:${NC}"
    echo -e "${DIM}  sudo systemctl stop x1-forge && sudo systemctl disable x1-forge${NC}"
    echo -e "${DIM}  sudo rm -rf /opt/x1-forge /mnt/x1-forge /etc/systemd/system/x1-forge.service${NC}"
    echo -e "${DIM}  sudo rm /usr/local/bin/x1-forge /usr/local/bin/x1-forge-config${NC}"
    echo -e "${DIM}  rm -rf ~/.config/x1-forge${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}To start your validator now:  x1-forge start${NC}"
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${DIM}You are solely responsible for securing your private keys.${NC}"
    echo -e "${DIM}We do not store, manage, or have access to your keys.${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

main() {
    # Check for config mode
    if [[ "$1" == "--config" ]] || [[ "$1" == "config" ]]; then
        show_config_menu
        exit 0
    fi

    # Ensure we can read from terminal even when piped
    # Save original stdin and redirect to terminal
    exec 3<&0
    exec < /dev/tty

    print_banner
    print_overview

    read -p "Ready to begin? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    fi

    check_requirements
    install_dependencies
    setup_wallets
    fund_identity
    create_vote_account
    setup_validator_identity
    build_and_install
    configure_firewall
    setup_service
    print_completion

    # Restore original stdin before exiting
    exec <&3
    exec 3<&-
}

main "$@"
exit 0
