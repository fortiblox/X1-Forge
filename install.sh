#!/bin/bash
# X1-Forge Installer
# Efficient Voting Validator for X1 Blockchain
#
# Usage: curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash

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
    echo "  6. Build the validator from source (compiles Tachyon)"
    echo "  7. Configure firewall ports (8000-8020, 8899)"
    echo "  8. Install systemd service for auto-start"
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
}

# ═══════════════════════════════════════════════════════════════
# STEP 1: System Requirements Check
# ═══════════════════════════════════════════════════════════════

check_requirements() {
    log_step "1/7" "Checking System Requirements"

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

    # OS Check
    if [[ "$OS" == "Linux" ]]; then
        log_success "Operating System: Linux"
    else
        log_error "Operating System: $OS (Linux required)"
        errors=$((errors + 1))
    fi

    # Architecture
    if [[ "$ARCH" == "x86_64" ]]; then
        log_success "Architecture: x86_64"
    else
        log_error "Architecture: $ARCH (x86_64 required)"
        errors=$((errors + 1))
    fi

    # CPU
    if [[ $CPU_CORES -ge 16 ]]; then
        log_success "CPU Cores: $CPU_CORES (recommended: 16+)"
    elif [[ $CPU_CORES -ge 8 ]]; then
        log_warn "CPU Cores: $CPU_CORES (minimum met, recommended: 16+)"
        warnings=$((warnings + 1))
    else
        log_error "CPU Cores: $CPU_CORES (minimum 8 required)"
        errors=$((errors + 1))
    fi

    # RAM
    if [[ $RAM_GB -ge 128 ]]; then
        log_success "RAM: ${RAM_GB}GB (recommended: 128GB+)"
    elif [[ $RAM_GB -ge 60 ]]; then
        log_warn "RAM: ${RAM_GB}GB (minimum met, recommended: 128GB+)"
        warnings=$((warnings + 1))
    else
        log_error "RAM: ${RAM_GB}GB (minimum 64GB required)"
        errors=$((errors + 1))
    fi

    # Disk
    if [[ $DISK_FREE_GB -ge 1000 ]]; then
        log_success "Disk Free: ${DISK_FREE_GB}GB (recommended: 1TB+)"
    elif [[ $DISK_FREE_GB -ge 400 ]]; then
        log_warn "Disk Free: ${DISK_FREE_GB}GB (minimum met, recommended: 1TB+)"
        warnings=$((warnings + 1))
    else
        log_error "Disk Free: ${DISK_FREE_GB}GB (minimum 400GB required)"
        errors=$((errors + 1))
    fi

    # Port check
    if command -v ss &>/dev/null; then
        if ss -tuln | grep -q ':8899 '; then
            log_warn "Port 8899 already in use"
            warnings=$((warnings + 1))
        else
            log_success "Port 8899: Available"
        fi
    fi

    # Summary
    echo ""
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}${BOLD}System does not meet minimum requirements.${NC}"
        echo "Please upgrade your hardware before continuing."
        exit 1
    elif [[ $warnings -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}System meets minimum requirements with warnings.${NC}"
        echo "Your validator will work, but performance may be limited."
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        echo -e "${GREEN}${BOLD}All requirements met!${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════
# STEP 2: Install Dependencies
# ═══════════════════════════════════════════════════════════════

install_dependencies() {
    log_step "2/7" "Installing Dependencies"

    echo "Installing build tools and libraries..."
    echo ""

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

    # Rust
    if command -v rustc &>/dev/null; then
        log_success "Rust already installed: $(rustc --version | cut -d' ' -f2)"
    else
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q
        source "$HOME/.cargo/env"
        log_success "Rust installed"
    fi

    # Solana CLI
    if command -v solana &>/dev/null; then
        log_success "Solana CLI already installed"
    else
        echo "Installing Solana CLI..."
        sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)" 2>/dev/null
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        log_success "Solana CLI installed"
    fi

    # Configure Solana for mainnet
    solana config set --url $RPC_URL -q
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: Wallet Setup
# ═══════════════════════════════════════════════════════════════

setup_wallets() {
    log_step "3/7" "Wallet Setup"

    mkdir -p "$CONFIG_DIR"

    IDENTITY_PATH="$CONFIG_DIR/identity.json"
    VOTE_PATH="$CONFIG_DIR/vote.json"

    echo "Your validator needs two keypairs:"
    echo "  1. ${BOLD}Identity${NC} - Your validator's unique identity on the network"
    echo "  2. ${BOLD}Vote Account${NC} - Receives staking delegations and rewards"
    echo ""

    # Check for existing keypairs
    if [[ -f "$IDENTITY_PATH" ]] || [[ -f "$VOTE_PATH" ]]; then
        echo -e "${YELLOW}Existing keypairs found:${NC}"
        [[ -f "$IDENTITY_PATH" ]] && echo "  Identity: $(solana-keygen pubkey $IDENTITY_PATH 2>/dev/null || echo 'invalid')"
        [[ -f "$VOTE_PATH" ]] && echo "  Vote: $(solana-keygen pubkey $VOTE_PATH 2>/dev/null || echo 'invalid')"
        echo ""
    fi

    echo "How would you like to set up your keypairs?"
    echo ""
    echo "  1) ${GREEN}Create NEW keypairs${NC} (fresh validator)"
    echo "  2) ${CYAN}Import EXISTING keypairs${NC} (migrating from another server)"
    echo "  3) ${YELLOW}Keep existing keypairs${NC} (already set up)"
    echo ""

    read -p "Select option [1-3]: " wallet_choice

    case $wallet_choice in
        1)
            create_new_wallets
            ;;
        2)
            import_existing_wallets
            ;;
        3)
            if [[ ! -f "$IDENTITY_PATH" ]] || [[ ! -f "$VOTE_PATH" ]]; then
                log_error "Existing keypairs not found. Please choose option 1 or 2."
                setup_wallets
                return
            fi
            log_success "Using existing keypairs"
            ;;
        *)
            log_error "Invalid option"
            setup_wallets
            return
            ;;
    esac

    # Display keypair info
    echo ""
    echo -e "${GREEN}${BOLD}Keypairs configured:${NC}"
    IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_PATH")
    echo "  Identity:     $IDENTITY_PUBKEY"
    echo "  Vote Account: $VOTE_PUBKEY"

    # Backup warning
    echo ""
    echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  CRITICAL: BACK UP YOUR KEYPAIRS NOW!                         ║${NC}"
    echo -e "${RED}${BOLD}║                                                               ║${NC}"
    echo -e "${RED}${BOLD}║  Copy these files to secure offline storage:                  ║${NC}"
    echo -e "${RED}${BOLD}║    $IDENTITY_PATH${NC}"
    echo -e "${RED}${BOLD}║    $VOTE_PATH${NC}"
    echo -e "${RED}${BOLD}║                                                               ║${NC}"
    echo -e "${RED}${BOLD}║  Loss of these files = LOSS OF YOUR VALIDATOR                 ║${NC}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Press Enter after you have backed up your keypairs..."
}

create_new_wallets() {
    echo ""
    log_info "Creating new identity keypair..."
    solana-keygen new -o "$IDENTITY_PATH" --no-passphrase --force -q
    chmod 600 "$IDENTITY_PATH"
    log_success "Identity created: $(solana-keygen pubkey $IDENTITY_PATH)"

    log_info "Creating new vote account keypair..."
    solana-keygen new -o "$VOTE_PATH" --no-passphrase --force -q
    chmod 600 "$VOTE_PATH"
    log_success "Vote account created: $(solana-keygen pubkey $VOTE_PATH)"
}

import_existing_wallets() {
    echo ""
    echo "Import options:"
    echo "  1) Provide file paths to existing keypair JSON files"
    echo "  2) Paste private key bytes (for recovery)"
    echo ""
    read -p "Select [1-2]: " import_method

    case $import_method in
        1)
            import_from_files
            ;;
        2)
            import_from_bytes
            ;;
        *)
            log_error "Invalid option"
            import_existing_wallets
            ;;
    esac
}

import_from_files() {
    echo ""
    read -p "Path to identity keypair JSON: " identity_source
    identity_source="${identity_source/#\~/$HOME}"
    if [[ -f "$identity_source" ]]; then
        cp "$identity_source" "$IDENTITY_PATH"
        chmod 600 "$IDENTITY_PATH"
        log_success "Identity imported: $(solana-keygen pubkey $IDENTITY_PATH)"
    else
        log_error "File not found: $identity_source"
        exit 1
    fi

    read -p "Path to vote account keypair JSON: " vote_source
    vote_source="${vote_source/#\~/$HOME}"
    if [[ -f "$vote_source" ]]; then
        cp "$vote_source" "$VOTE_PATH"
        chmod 600 "$VOTE_PATH"
        log_success "Vote account imported: $(solana-keygen pubkey $VOTE_PATH)"
    else
        log_error "File not found: $vote_source"
        exit 1
    fi
}

import_from_bytes() {
    echo ""
    echo "Paste your identity private key as JSON array (e.g., [1,2,3,...]):"
    read -r identity_bytes
    echo "$identity_bytes" > "$IDENTITY_PATH"
    chmod 600 "$IDENTITY_PATH"

    if solana-keygen pubkey "$IDENTITY_PATH" &>/dev/null; then
        log_success "Identity imported: $(solana-keygen pubkey $IDENTITY_PATH)"
    else
        log_error "Invalid identity key format"
        rm -f "$IDENTITY_PATH"
        exit 1
    fi

    echo ""
    echo "Paste your vote account private key as JSON array:"
    read -r vote_bytes
    echo "$vote_bytes" > "$VOTE_PATH"
    chmod 600 "$VOTE_PATH"

    if solana-keygen pubkey "$VOTE_PATH" &>/dev/null; then
        log_success "Vote account imported: $(solana-keygen pubkey $VOTE_PATH)"
    else
        log_error "Invalid vote key format"
        rm -f "$VOTE_PATH"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: Fund Identity Wallet
# ═══════════════════════════════════════════════════════════════

fund_identity() {
    log_step "4/7" "Fund Identity Wallet"

    IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")

    # Check current balance
    BALANCE=$(solana balance "$IDENTITY_PATH" --url $RPC_URL 2>/dev/null | awk '{print $1}' || echo "0")

    echo "Your identity wallet pays for vote transaction fees."
    echo "Minimum recommended: ${BOLD}0.5 XNT${NC}"
    echo ""
    echo "Current balance: ${BOLD}$BALANCE XNT${NC}"
    echo ""

    if (( $(echo "$BALANCE >= 0.5" | bc -l 2>/dev/null || echo 0) )); then
        log_success "Wallet is funded!"
        return
    fi

    echo -e "${CYAN}${BOLD}Send XNT to this address:${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}$IDENTITY_PUBKEY${NC}"
    echo ""
    echo "You can send from:"
    echo "  - An exchange (withdrawal to this address)"
    echo "  - Another wallet: solana transfer $IDENTITY_PUBKEY <AMOUNT> --url $RPC_URL"
    echo ""

    echo "Waiting for funds to arrive..."
    echo "(Checking every 30 seconds. Press Ctrl+C to skip and fund later)"
    echo ""

    while true; do
        BALANCE=$(solana balance "$IDENTITY_PATH" --url $RPC_URL 2>/dev/null | awk '{print $1}' || echo "0")

        if (( $(echo "$BALANCE >= 0.1" | bc -l 2>/dev/null || echo 0) )); then
            echo ""
            log_success "Funds received! Balance: $BALANCE XNT"
            break
        fi

        echo -ne "\r  Balance: $BALANCE XNT - Waiting...  "
        sleep 30
    done
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: Create Vote Account On-Chain
# ═══════════════════════════════════════════════════════════════

create_vote_account() {
    log_step "5/7" "Create Vote Account On-Chain"

    IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_PATH")

    # Check if vote account already exists
    if solana vote-account "$VOTE_PATH" --url $RPC_URL &>/dev/null; then
        log_success "Vote account already exists on-chain"
        return
    fi

    echo "Your vote account needs to be created on the blockchain."
    echo ""
    echo "The ${BOLD}withdrawer${NC} is the wallet that can withdraw your staking rewards."
    echo -e "${YELLOW}Tip: Use a separate secure wallet (cold storage) as withdrawer,${NC}"
    echo -e "${YELLOW}     not your validator identity, for better security.${NC}"
    echo ""

    echo "Withdrawer options:"
    echo "  1) Enter a separate wallet address (recommended)"
    echo "  2) Use my identity as withdrawer (simpler, less secure)"
    echo ""
    read -p "Select [1-2]: " withdrawer_choice

    case $withdrawer_choice in
        1)
            read -p "Enter withdrawer public key: " WITHDRAWER_PUBKEY
            ;;
        2)
            WITHDRAWER_PUBKEY="$IDENTITY_PUBKEY"
            log_warn "Using identity as withdrawer. Consider changing this later for security."
            ;;
        *)
            WITHDRAWER_PUBKEY="$IDENTITY_PUBKEY"
            ;;
    esac

    echo ""
    echo "Set your commission rate (percentage of staking rewards you keep):"
    echo "  Common rates: 5%, 10%, 15%"
    echo ""
    read -p "Commission percentage [default: 10]: " COMMISSION
    COMMISSION=${COMMISSION:-10}

    echo ""
    log_info "Creating vote account on-chain..."
    echo "  Vote Account: $VOTE_PUBKEY"
    echo "  Authority: $IDENTITY_PUBKEY"
    echo "  Withdrawer: $WITHDRAWER_PUBKEY"
    echo "  Commission: $COMMISSION%"
    echo ""

    if solana create-vote-account "$VOTE_PATH" "$IDENTITY_PATH" "$WITHDRAWER_PUBKEY" \
        --commission "$COMMISSION" \
        --url $RPC_URL \
        --keypair "$IDENTITY_PATH"; then
        log_success "Vote account created successfully!"
    else
        log_error "Failed to create vote account. You can retry manually later:"
        echo "  solana create-vote-account $VOTE_PATH $IDENTITY_PATH $WITHDRAWER_PUBKEY --commission $COMMISSION --url $RPC_URL"
    fi
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: Build and Install Validator
# ═══════════════════════════════════════════════════════════════

build_and_install() {
    log_step "6/7" "Build and Install Validator"

    # Create directories
    sudo mkdir -p "$INSTALL_DIR"/{bin,lib,backups}
    sudo mkdir -p "$DATA_DIR"/ledger
    sudo chown -R "$USER:$USER" "$DATA_DIR" 2>/dev/null || true

    # Build validator
    echo "Building X1-Forge from Tachyon source..."
    echo "This takes 15-30 minutes on first build."
    echo ""

    cd /tmp
    rm -rf tachyon-build

    git clone --depth 1 https://github.com/$TACHYON_REPO.git tachyon-build
    cd tachyon-build

    export RUSTFLAGS="-C target-cpu=native"
    cargo build --release -p tachyon-validator 2>&1 | while read line; do
        echo -ne "\r  Building... $line                    \r"
    done

    sudo cp target/release/tachyon-validator "$INSTALL_DIR/bin/x1-forge"
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge"
    echo "$FORGE_VERSION" | sudo tee "$INSTALL_DIR/version" > /dev/null

    cd /
    rm -rf /tmp/tachyon-build

    log_success "Validator binary built"

    # Install CLI wrapper
    install_cli_wrapper

    # Apply kernel tuning
    apply_kernel_tuning

    # Install systemd service
    install_systemd_service

    log_success "X1-Forge installed successfully!"
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
        echo ""
        echo "Commands:"
        echo "  start/stop/restart  - Control validator"
        echo "  status              - Show service status"
        echo "  logs                - Follow logs"
        echo "  catchup             - Show sync progress"
        echo "  health              - Health check"
        ;;
esac
WRAPPER
    sudo chmod +x "$BIN_DIR/x1-forge"
}

apply_kernel_tuning() {
    sudo tee /etc/sysctl.d/99-x1-forge.conf > /dev/null << 'EOF'
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_default=134217728
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

install_systemd_service() {
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
    sudo systemctl enable x1-forge
}

# ═══════════════════════════════════════════════════════════════
# STEP 7: Configure Firewall
# ═══════════════════════════════════════════════════════════════

configure_firewall() {
    log_step "7/7" "Configuring Firewall"

    log_info "Opening required ports..."
    echo ""
    echo "Required ports:"
    echo "  - 8000-8020 (UDP/TCP): Gossip and data transfer"
    echo "  - 8899 (TCP): RPC"
    echo ""

    # Detect and configure firewall
    if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        log_info "Detected UFW firewall, configuring..."
        sudo ufw allow 8000:8020/tcp >/dev/null 2>&1
        sudo ufw allow 8000:8020/udp >/dev/null 2>&1
        sudo ufw allow 8899/tcp >/dev/null 2>&1
        log_success "UFW rules added"

    elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
        log_info "Detected firewalld, configuring..."
        sudo firewall-cmd --permanent --add-port=8000-8020/tcp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=8000-8020/udp >/dev/null 2>&1
        sudo firewall-cmd --permanent --add-port=8899/tcp >/dev/null 2>&1
        sudo firewall-cmd --reload >/dev/null 2>&1
        log_success "Firewalld rules added"

    elif command -v iptables &>/dev/null; then
        log_info "Configuring iptables..."
        sudo iptables -A INPUT -p tcp --dport 8000:8020 -j ACCEPT 2>/dev/null || true
        sudo iptables -A INPUT -p udp --dport 8000:8020 -j ACCEPT 2>/dev/null || true
        sudo iptables -A INPUT -p tcp --dport 8899 -j ACCEPT 2>/dev/null || true

        # Try to save rules
        if command -v netfilter-persistent &>/dev/null; then
            sudo netfilter-persistent save >/dev/null 2>&1 || true
        elif [[ -f /etc/sysconfig/iptables ]]; then
            sudo service iptables save >/dev/null 2>&1 || true
        fi
        log_success "iptables rules added"
    else
        log_warn "No firewall detected or firewall inactive"
        echo ""
        echo -e "${YELLOW}Please manually open these ports if you have a firewall:${NC}"
        echo "  - 8000-8020/tcp and 8000-8020/udp"
        echo "  - 8899/tcp"
    fi

    # Cloud provider note
    echo ""
    echo -e "${DIM}Note: If running on a cloud provider (AWS, GCP, Azure, etc.),${NC}"
    echo -e "${DIM}also configure the security group/firewall rules in your provider's console.${NC}"
}

# ═══════════════════════════════════════════════════════════════
# Completion
# ═══════════════════════════════════════════════════════════════

print_completion() {
    IDENTITY_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/identity.json")
    VOTE_PUBKEY=$(solana-keygen pubkey "$CONFIG_DIR/vote.json")

    clear
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║   X1-Forge Installation Complete!                             ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Your Validator:${NC}"
    echo "  Identity:     $IDENTITY_PUBKEY"
    echo "  Vote Account: $VOTE_PUBKEY"
    echo ""
    echo -e "${BOLD}Start your validator:${NC}"
    echo "  sudo systemctl start x1-forge"
    echo ""
    echo -e "${BOLD}Monitor:${NC}"
    echo "  x1-forge logs      - Watch logs"
    echo "  x1-forge catchup   - Sync progress"
    echo "  x1-forge status    - Service status"
    echo ""
    echo -e "${YELLOW}Initial sync takes several hours. Your validator will start${NC}"
    echo -e "${YELLOW}voting automatically once caught up with the network.${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

main() {
    print_banner
    print_overview

    read -p "Ready to begin? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    check_requirements
    install_dependencies
    setup_wallets
    fund_identity
    create_vote_account
    build_and_install
    configure_firewall
    print_completion
}

main "$@"
