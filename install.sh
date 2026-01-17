#!/bin/bash
# X1-Forge Installer
# Efficient Voting Validator for X1 Blockchain
#
# Usage: curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
#
# X1-Forge runs a stripped-down Tachyon validator optimized for voting
# and earning staking rewards on lower-spec hardware (64GB RAM).
# Removed: MEV, Geyser plugins, full RPC API

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FORGE_VERSION="1.0.0"
TACHYON_REPO="x1-labs/tachyon"
INSTALL_DIR="/opt/x1-forge"
CONFIG_DIR="$HOME/.config/x1-forge"
DATA_DIR="/mnt/x1-forge"
BIN_DIR="/usr/local/bin"

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
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                                                           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   ${GREEN}X1-Forge${NC} - Efficient Voting Validator for X1          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   Version: ${FORGE_VERSION}                                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                           ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}X1-Forge votes on blocks and earns staking rewards.${NC}"
    echo -e "${YELLOW}Stripped features: No MEV, No Geyser, No full RPC API${NC}"
    echo ""
}

detect_system() {
    log_info "Detecting system specifications..."

    OS=$(uname -s)
    ARCH=$(uname -m)

    if [[ "$OS" != "Linux" ]]; then
        log_error "X1-Forge only supports Linux. Detected: $OS"
        exit 1
    fi

    if [[ "$ARCH" != "x86_64" ]]; then
        log_error "X1-Forge only supports x86_64. Detected: $ARCH"
        exit 1
    fi

    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$((RAM_KB / 1024 / 1024))
    DISK_FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

    echo ""
    echo "System Specifications:"
    echo "  OS:        $OS ($ARCH)"
    echo "  CPU:       $CPU_MODEL ($CPU_CORES cores)"
    echo "  RAM:       ${RAM_GB}GB"
    echo "  Disk Free: ${DISK_FREE_GB}GB"
    echo ""
}

check_requirements() {
    log_info "Checking minimum requirements..."

    local errors=0

    # Minimum 64GB RAM for voting validator
    if [[ $RAM_GB -lt 60 ]]; then
        log_error "Insufficient RAM: ${RAM_GB}GB (minimum 64GB required)"
        errors=$((errors + 1))
    else
        log_success "RAM: ${RAM_GB}GB"
    fi

    # Minimum 8 cores
    if [[ $CPU_CORES -lt 8 ]]; then
        log_error "Insufficient CPU: ${CPU_CORES} cores (minimum 8 required)"
        errors=$((errors + 1))
    else
        log_success "CPU: ${CPU_CORES} cores"
    fi

    # Minimum 400GB disk
    if [[ $DISK_FREE_GB -lt 400 ]]; then
        log_error "Insufficient disk: ${DISK_FREE_GB}GB (minimum 400GB required)"
        errors=$((errors + 1))
    else
        log_success "Disk: ${DISK_FREE_GB}GB free"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "System does not meet minimum requirements"
        exit 1
    fi

    log_success "All requirements met!"
}

install_dependencies() {
    log_info "Installing system dependencies..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            pkg-config \
            libssl-dev \
            libudev-dev \
            libclang-dev \
            protobuf-compiler \
            curl wget git jq zstd
    elif command -v yum &>/dev/null; then
        sudo yum install -y \
            gcc gcc-c++ make \
            pkgconfig openssl-devel systemd-devel clang \
            protobuf-compiler curl wget git jq zstd
    fi

    log_success "Dependencies installed"
}

install_rust() {
    if command -v rustc &>/dev/null; then
        log_success "Rust already installed: $(rustc --version)"
    else
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        log_success "Rust installed"
    fi
}

create_directories() {
    log_info "Creating directory structure..."

    sudo mkdir -p "$INSTALL_DIR"/{bin,lib,backups}
    mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$DATA_DIR"/ledger

    if [[ $EUID -ne 0 ]]; then
        sudo chown -R "$USER:$USER" "$DATA_DIR"
    fi

    log_success "Directories created"
}

build_validator() {
    log_info "Building X1-Forge (Tachyon voting validator)..."
    log_warn "This will take 15-30 minutes on first build..."

    cd /tmp
    rm -rf tachyon-build

    git clone --depth 1 https://github.com/$TACHYON_REPO.git tachyon-build
    cd tachyon-build

    # Build with optimizations
    export RUSTFLAGS="-C target-cpu=native"
    cargo build --release -p tachyon-validator

    # Install binary
    sudo cp target/release/tachyon-validator "$INSTALL_DIR/bin/x1-forge"
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge"

    # Save version
    echo "$FORGE_VERSION" | sudo tee "$INSTALL_DIR/version" > /dev/null

    # Cleanup
    cd /
    rm -rf /tmp/tachyon-build

    log_success "X1-Forge built successfully"
}

generate_keypairs() {
    log_info "Keypair Setup..."

    # Install solana CLI for keygen
    if ! command -v solana-keygen &>/dev/null; then
        sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    fi

    IDENTITY_PATH="$CONFIG_DIR/identity.json"
    VOTE_PATH="$CONFIG_DIR/vote.json"

    if [[ -f "$IDENTITY_PATH" ]]; then
        log_warn "Identity already exists: $(solana-keygen pubkey $IDENTITY_PATH)"
    else
        solana-keygen new -o "$IDENTITY_PATH" --no-passphrase --force
        chmod 600 "$IDENTITY_PATH"
        log_success "Identity: $(solana-keygen pubkey $IDENTITY_PATH)"
    fi

    if [[ -f "$VOTE_PATH" ]]; then
        log_warn "Vote account already exists: $(solana-keygen pubkey $VOTE_PATH)"
    else
        solana-keygen new -o "$VOTE_PATH" --no-passphrase --force
        chmod 600 "$VOTE_PATH"
        log_success "Vote Account: $(solana-keygen pubkey $VOTE_PATH)"
    fi

    echo ""
    echo -e "${YELLOW}IMPORTANT: Back up these keypair files securely!${NC}"
    echo "  Identity:     $IDENTITY_PATH"
    echo "  Vote Account: $VOTE_PATH"
    echo ""
}

create_wrapper() {
    log_info "Creating CLI wrapper..."

    sudo tee "$BIN_DIR/x1-forge" > /dev/null << 'WRAPPER'
#!/bin/bash
INSTALL_DIR="/opt/x1-forge"
CONFIG_DIR="$HOME/.config/x1-forge"

case "$1" in
    start)   sudo systemctl start x1-forge ;;
    stop)    sudo systemctl stop x1-forge ;;
    restart) sudo systemctl restart x1-forge ;;
    status)  sudo systemctl status x1-forge ;;
    logs)    journalctl -u x1-forge -f ;;
    catchup) solana catchup --our-localhost ;;
    health)  curl -s http://localhost:8899/health 2>/dev/null || echo "Not responding" ;;
    *)
        echo "X1-Forge - Efficient Voting Validator"
        echo ""
        echo "Usage: x1-forge <command>"
        echo ""
        echo "Commands:"
        echo "  start    Start the validator"
        echo "  stop     Stop the validator"
        echo "  restart  Restart the validator"
        echo "  status   Show status"
        echo "  logs     Follow logs"
        echo "  catchup  Show sync progress"
        echo "  health   Health check"
        ;;
esac
WRAPPER
    sudo chmod +x "$BIN_DIR/x1-forge"
    log_success "CLI wrapper created"
}

apply_kernel_tuning() {
    log_info "Applying kernel optimizations..."

    sudo tee /etc/sysctl.d/99-x1-forge.conf > /dev/null << 'EOF'
# X1-Forge Kernel Tuning
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_default=134217728
net.core.netdev_max_backlog=100000
net.ipv4.tcp_max_syn_backlog=100000
net.core.somaxconn=100000
net.ipv4.tcp_tw_reuse=1
vm.max_map_count=2000000
vm.swappiness=10
fs.file-max=2097152
EOF

    sudo sysctl -p /etc/sysctl.d/99-x1-forge.conf 2>/dev/null || true

    sudo tee /etc/security/limits.d/99-x1-forge.conf > /dev/null << EOF
$USER soft nofile 1000000
$USER hard nofile 1000000
EOF

    log_success "Kernel optimizations applied"
}

install_systemd_service() {
    log_info "Installing systemd service..."

    sudo tee /etc/systemd/system/x1-forge.service > /dev/null << EOF
[Unit]
Description=X1-Forge Voting Validator
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Environment="RUST_LOG=solana_metrics=warn,info"
WorkingDirectory=$DATA_DIR

ExecStart=$INSTALL_DIR/bin/x1-forge \\
    --identity $CONFIG_DIR/identity.json \\
    --vote-account $CONFIG_DIR/vote.json \\
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
    --full-snapshot-interval-slots 10000 \\
    --maximum-full-snapshots-to-retain 2 \\
    --maximum-incremental-snapshots-to-retain 2 \\
    --log $DATA_DIR/forge.log

Restart=on-failure
RestartSec=30
LimitNOFILE=1000000
LimitNPROC=500000
MemoryMax=60G

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable x1-forge

    log_success "Systemd service installed"
}

print_completion() {
    IDENTITY_PUBKEY=$(solana-keygen pubkey $CONFIG_DIR/identity.json 2>/dev/null || echo "Unknown")
    VOTE_PUBKEY=$(solana-keygen pubkey $CONFIG_DIR/vote.json 2>/dev/null || echo "Unknown")

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}   ${GREEN}X1-Forge Installation Complete!${NC}                        ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Validator Identity: $IDENTITY_PUBKEY"
    echo "Vote Account:       $VOTE_PUBKEY"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Fund your identity wallet with XNT for vote fees"
    echo "     solana transfer $IDENTITY_PUBKEY 1 --url https://rpc.mainnet.x1.xyz"
    echo ""
    echo "  2. Create vote account on-chain"
    echo "     solana create-vote-account $CONFIG_DIR/vote.json \\"
    echo "       $CONFIG_DIR/identity.json <WITHDRAWER_PUBKEY> \\"
    echo "       --commission 10 --url https://rpc.mainnet.x1.xyz"
    echo ""
    echo "  3. Start the validator"
    echo "     sudo systemctl start x1-forge"
    echo ""
    echo "  4. Monitor"
    echo "     x1-forge logs"
    echo "     x1-forge catchup"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Back up your keypair files!${NC}"
    echo ""
}

main() {
    print_banner
    detect_system
    check_requirements

    echo ""
    read -p "Proceed with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    install_dependencies
    install_rust
    create_directories
    build_validator
    generate_keypairs
    create_wrapper
    apply_kernel_tuning
    install_systemd_service
    print_completion
}

main "$@"
