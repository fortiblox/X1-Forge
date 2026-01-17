#!/bin/bash
# X1-Forge Installer
# Efficient Voting Validator for X1 Blockchain
#
# Usage: curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
#
# This script will:
# 1. Check system requirements
# 2. Install dependencies
# 3. Download and install X1-Forge
# 4. Generate keypairs (optional)
# 5. Configure systemd service
# 6. Download snapshot and start syncing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FORGE_VERSION="1.0.0"
FORGE_REPO="fortiblox/X1-Forge"
TACHYON_REPO="x1-labs/tachyon"
INSTALL_DIR="/opt/x1-forge"
CONFIG_DIR="$HOME/.config/x1-forge"
DATA_DIR="/mnt/x1-forge"
BIN_DIR="/usr/local/bin"

# X1 Mainnet Configuration (DO NOT MODIFY)
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

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                                                           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   ${GREEN}X1-Forge${NC} - Efficient Voting Validator for X1          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   Version: ${FORGE_VERSION}                                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                           ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. Consider creating a dedicated 'validator' user."
    fi
}

# Detect system specifications
detect_system() {
    log_info "Detecting system specifications..."

    OS=$(uname -s)
    ARCH=$(uname -m)

    if [[ "$OS" != "Linux" ]]; then
        log_error "X1-Forge only supports Linux. Detected: $OS"
        exit 1
    fi

    if [[ "$ARCH" != "x86_64" ]]; then
        log_error "X1-Forge only supports x86_64 architecture. Detected: $ARCH"
        exit 1
    fi

    # Detect CPU
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)

    # Detect RAM
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$((RAM_KB / 1024 / 1024))

    # Detect disk
    DISK_FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

    echo ""
    echo "System Specifications:"
    echo "  OS:        $OS ($ARCH)"
    echo "  CPU:       $CPU_MODEL ($CPU_CORES cores)"
    echo "  RAM:       ${RAM_GB}GB"
    echo "  Disk Free: ${DISK_FREE_GB}GB"
    echo ""
}

# Check minimum requirements
check_requirements() {
    log_info "Checking minimum requirements..."

    local errors=0

    # Check RAM (minimum 64GB)
    if [[ $RAM_GB -lt 60 ]]; then
        log_error "Insufficient RAM: ${RAM_GB}GB (minimum 64GB required)"
        errors=$((errors + 1))
    else
        log_success "RAM: ${RAM_GB}GB"
    fi

    # Check CPU (minimum 8 cores)
    if [[ $CPU_CORES -lt 8 ]]; then
        log_error "Insufficient CPU: ${CPU_CORES} cores (minimum 8 required)"
        errors=$((errors + 1))
    else
        log_success "CPU: ${CPU_CORES} cores"
    fi

    # Check disk (minimum 400GB free)
    if [[ $DISK_FREE_GB -lt 400 ]]; then
        log_error "Insufficient disk space: ${DISK_FREE_GB}GB (minimum 400GB required)"
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

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            pkg-config \
            libssl-dev \
            libudev-dev \
            libclang-dev \
            protobuf-compiler \
            curl \
            wget \
            git \
            jq \
            aria2 \
            zstd
    elif command -v yum &>/dev/null; then
        sudo yum install -y \
            gcc \
            gcc-c++ \
            make \
            pkgconfig \
            openssl-devel \
            systemd-devel \
            clang \
            protobuf-compiler \
            curl \
            wget \
            git \
            jq \
            aria2 \
            zstd
    else
        log_error "Unsupported package manager. Please install dependencies manually."
        exit 1
    fi

    log_success "Dependencies installed"
}

# Install Rust if not present
install_rust() {
    if command -v rustc &>/dev/null; then
        RUST_VERSION=$(rustc --version)
        log_success "Rust already installed: $RUST_VERSION"
    else
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        log_success "Rust installed"
    fi
}

# Install Solana CLI tools
install_solana_cli() {
    if command -v solana &>/dev/null; then
        SOLANA_VERSION=$(solana --version)
        log_success "Solana CLI already installed: $SOLANA_VERSION"
    else
        log_info "Installing Solana CLI..."
        sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        log_success "Solana CLI installed"
    fi
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."

    sudo mkdir -p "$INSTALL_DIR"/{bin,lib,share}
    mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$DATA_DIR"/ledger

    # Set ownership if not root
    if [[ $EUID -ne 0 ]]; then
        sudo chown -R "$USER:$USER" "$DATA_DIR"
    fi

    log_success "Directories created"
}

# Download and build X1-Forge (or download pre-built binary)
install_forge() {
    log_info "Installing X1-Forge..."

    # For now, we'll use the existing tachyon binary approach
    # In production, this would download pre-built optimized binaries

    # Check if tachyon binary exists in known locations
    TACHYON_BIN=""
    for path in \
        "/root/x1-validator-bundle/validator/tachyon-mev/target/release/tachyon-validator" \
        "/opt/tachyon/target/release/tachyon-validator" \
        "$HOME/tachyon/target/release/tachyon-validator"; do
        if [[ -f "$path" ]]; then
            TACHYON_BIN="$path"
            break
        fi
    done

    if [[ -z "$TACHYON_BIN" ]]; then
        log_info "Tachyon binary not found. Building from source..."
        log_warn "This will take 15-30 minutes..."

        cd /tmp
        git clone https://github.com/x1-labs/tachyon.git x1-forge-build
        cd x1-forge-build

        # Build with optimizations
        cargo build --release -p tachyon-validator

        TACHYON_BIN="/tmp/x1-forge-build/target/release/tachyon-validator"
    fi

    # Copy binary
    sudo cp "$TACHYON_BIN" "$INSTALL_DIR/bin/x1-forge-validator"
    sudo chmod +x "$INSTALL_DIR/bin/x1-forge-validator"

    # Create wrapper script
    sudo tee "$BIN_DIR/x1-forge" > /dev/null << 'WRAPPER'
#!/bin/bash
# X1-Forge CLI wrapper

INSTALL_DIR="/opt/x1-forge"
CONFIG_DIR="$HOME/.config/x1-forge"

case "$1" in
    start)
        sudo systemctl start x1-forge
        ;;
    stop)
        sudo systemctl stop x1-forge
        ;;
    restart)
        sudo systemctl restart x1-forge
        ;;
    status)
        sudo systemctl status x1-forge
        ;;
    logs)
        journalctl -u x1-forge -f
        ;;
    health)
        curl -s http://localhost:8899/health 2>/dev/null || echo "Validator not responding"
        ;;
    update)
        shift
        $INSTALL_DIR/bin/x1-forge-update "$@"
        ;;
    rollback)
        $INSTALL_DIR/bin/x1-forge-rollback
        ;;
    *)
        echo "X1-Forge - Efficient Voting Validator"
        echo ""
        echo "Usage: x1-forge <command>"
        echo ""
        echo "Commands:"
        echo "  start      Start the validator"
        echo "  stop       Stop the validator"
        echo "  restart    Restart the validator"
        echo "  status     Show validator status"
        echo "  logs       Follow validator logs"
        echo "  health     Check validator health"
        echo "  update     Check for and apply updates"
        echo "  rollback   Rollback to previous version"
        ;;
esac
WRAPPER
    sudo chmod +x "$BIN_DIR/x1-forge"

    log_success "X1-Forge installed to $INSTALL_DIR"
}

# Generate keypairs
generate_keypairs() {
    log_info "Keypair Setup"

    IDENTITY_PATH="$CONFIG_DIR/forge-identity.json"
    VOTE_PATH="$CONFIG_DIR/forge-vote.json"

    if [[ -f "$IDENTITY_PATH" ]]; then
        log_warn "Identity keypair already exists at $IDENTITY_PATH"
        read -p "Generate new keypair? This will overwrite existing! (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")
            log_info "Using existing identity: $IDENTITY_PUBKEY"

            if [[ -f "$VOTE_PATH" ]]; then
                VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_PATH")
                log_info "Using existing vote account: $VOTE_PUBKEY"
            fi
            return
        fi
    fi

    log_info "Generating validator identity keypair..."
    solana-keygen new -o "$IDENTITY_PATH" --no-passphrase --force
    IDENTITY_PUBKEY=$(solana-keygen pubkey "$IDENTITY_PATH")
    log_success "Identity: $IDENTITY_PUBKEY"

    log_info "Generating vote account keypair..."
    solana-keygen new -o "$VOTE_PATH" --no-passphrase --force
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_PATH")
    log_success "Vote Account: $VOTE_PUBKEY"

    # Secure the keypairs
    chmod 600 "$IDENTITY_PATH" "$VOTE_PATH"

    echo ""
    echo -e "${YELLOW}IMPORTANT: Back up these keypair files securely!${NC}"
    echo "  Identity:     $IDENTITY_PATH"
    echo "  Vote Account: $VOTE_PATH"
    echo ""
}

# Generate optimized configuration
generate_config() {
    log_info "Generating optimized configuration..."

    # Calculate optimal settings based on hardware
    local LEDGER_SIZE=10000000  # ~50GB
    local SNAPSHOT_INTERVAL=10000
    local MAX_FULL_SNAPSHOTS=2
    local MAX_INC_SNAPSHOTS=2

    # Adjust for available RAM
    if [[ $RAM_GB -ge 128 ]]; then
        LEDGER_SIZE=20000000
        MAX_FULL_SNAPSHOTS=4
    fi

    cat > "$CONFIG_DIR/config.toml" << EOF
# X1-Forge Configuration
# Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
# Hardware: ${CPU_CORES} cores, ${RAM_GB}GB RAM

[network]
cluster = "mainnet"

[paths]
ledger = "$DATA_DIR/ledger"
identity = "$CONFIG_DIR/forge-identity.json"
vote_account = "$CONFIG_DIR/forge-vote.json"
log = "$DATA_DIR/forge.log"

[performance]
# Optimized for ${RAM_GB}GB RAM system
ledger_size = $LEDGER_SIZE
snapshot_interval = $SNAPSHOT_INTERVAL
max_full_snapshots = $MAX_FULL_SNAPSHOTS
max_incremental_snapshots = $MAX_INC_SNAPSHOTS

[entrypoints]
# X1 Mainnet (DO NOT MODIFY)
endpoints = [
    "entrypoint0.mainnet.x1.xyz:8001",
    "entrypoint1.mainnet.x1.xyz:8001",
    "entrypoint2.mainnet.x1.xyz:8001"
]

[known_validators]
# X1 Mainnet trusted validators
pubkeys = [
    "7ufaUVtQKzGu5tpFtii9Cg8kR4jcpjQSXwsF3oVPSMZA",
    "5Rzytnub9yGTFHqSmauFLsAbdXFbehMwPBLiuEgKajUN",
    "4V2QkkWce8bwTzvvwPiNRNQ4W433ZsGQi9aWU12Q8uBF",
    "CkMwg4TM6jaSC5rJALQjvLc51XFY5pJ1H9f1Tmu5Qdxs",
    "7J5wJaH55ZYjCCmCMt7Gb3QL6FGFmjz5U8b6NcbzfoTy"
]
EOF

    log_success "Configuration saved to $CONFIG_DIR/config.toml"
}

# Install systemd service
install_systemd_service() {
    log_info "Installing systemd service..."

    # Build entrypoint args
    local ENTRYPOINT_ARGS=""
    for ep in "${ENTRYPOINTS[@]}"; do
        ENTRYPOINT_ARGS+="    --entrypoint $ep \\\\\n"
    done

    # Build known validator args
    local VALIDATOR_ARGS=""
    for v in "${KNOWN_VALIDATORS[@]}"; do
        VALIDATOR_ARGS+="    --known-validator $v \\\\\n"
    done

    sudo tee /etc/systemd/system/x1-forge.service > /dev/null << EOF
[Unit]
Description=X1-Forge Voting Validator
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Environment="PATH=$HOME/.local/share/solana/install/active_release/bin:/usr/local/bin:/usr/bin"
Environment="RUST_LOG=solana_metrics=warn,info"
Environment="MALLOC_CONF=background_thread:true,dirty_decay_ms:10000,muzzy_decay_ms:10000"
WorkingDirectory=$DATA_DIR

ExecStart=$INSTALL_DIR/bin/x1-forge-validator \\
    --identity $CONFIG_DIR/forge-identity.json \\
    --vote-account $CONFIG_DIR/forge-vote.json \\
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
    --rpc-port 8899 \\
    --dynamic-port-range 8000-8020 \\
    --wal-recovery-mode skip_any_corrupted_record \\
    --limit-ledger-size 10000000 \\
    --full-snapshot-interval-slots 10000 \\
    --maximum-full-snapshots-to-retain 2 \\
    --maximum-incremental-snapshots-to-retain 2 \\
    --log $DATA_DIR/forge.log

# Resource limits for 64GB+ system
MemoryMax=60G
CPUQuota=90%
LimitNOFILE=1000000
LimitNPROC=500000

# Restart behavior
Restart=on-failure
RestartSec=30
TimeoutStartSec=600
TimeoutStopSec=300

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=x1-forge

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable x1-forge

    log_success "Systemd service installed"
}

# Apply kernel tuning
apply_kernel_tuning() {
    log_info "Applying kernel optimizations..."

    sudo tee /etc/sysctl.d/99-x1-forge.conf > /dev/null << 'EOF'
# X1-Forge Kernel Tuning

# Network buffers
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_default=134217728
net.core.netdev_max_backlog=100000

# TCP tuning
net.ipv4.tcp_max_syn_backlog=100000
net.core.somaxconn=100000
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=8000 65535

# Memory
vm.max_map_count=2000000
vm.swappiness=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10

# File handles
fs.file-max=2097152
fs.nr_open=2097152
EOF

    sudo sysctl -p /etc/sysctl.d/99-x1-forge.conf

    # Set file descriptor limits
    sudo tee /etc/security/limits.d/99-x1-forge.conf > /dev/null << EOF
$USER soft nofile 1000000
$USER hard nofile 1000000
$USER soft nproc 500000
$USER hard nproc 500000
EOF

    log_success "Kernel optimizations applied"
}

# Print completion message
print_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                           ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}   ${GREEN}X1-Forge Installation Complete!${NC}                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                           ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your validator keypairs:"
    echo "  Identity:     $(solana-keygen pubkey $CONFIG_DIR/forge-identity.json 2>/dev/null || echo 'Not found')"
    echo "  Vote Account: $(solana-keygen pubkey $CONFIG_DIR/forge-vote.json 2>/dev/null || echo 'Not found')"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Fund your identity wallet with XNT for vote transaction fees"
    echo "     solana transfer <IDENTITY_PUBKEY> 1 --url https://rpc.mainnet.x1.xyz"
    echo ""
    echo "  2. Create vote account on-chain (requires funded identity)"
    echo "     solana create-vote-account $CONFIG_DIR/forge-vote.json \\"
    echo "       $CONFIG_DIR/forge-identity.json <WITHDRAWER_PUBKEY> \\"
    echo "       --commission 10 --url https://rpc.mainnet.x1.xyz"
    echo ""
    echo "  3. Start the validator"
    echo "     sudo systemctl start x1-forge"
    echo ""
    echo "  4. Monitor logs"
    echo "     journalctl -u x1-forge -f"
    echo ""
    echo "Commands:"
    echo "  x1-forge start    - Start validator"
    echo "  x1-forge stop     - Stop validator"
    echo "  x1-forge status   - Check status"
    echo "  x1-forge logs     - View logs"
    echo "  x1-forge health   - Health check"
    echo "  x1-forge update   - Check for updates"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Back up your keypair files!${NC}"
    echo "  $CONFIG_DIR/forge-identity.json"
    echo "  $CONFIG_DIR/forge-vote.json"
    echo ""
}

# Main installation flow
main() {
    print_banner
    check_root
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
    install_solana_cli
    create_directories
    install_forge
    generate_keypairs
    generate_config
    install_systemd_service
    apply_kernel_tuning

    print_completion
}

# Run main function
main "$@"
