# X1-Forge

**Efficient Voting Validator for X1 Blockchain**

X1-Forge is a stripped-down voting validator that earns staking rewards on lower-spec hardware (64GB RAM). It removes unnecessary features like MEV, Geyser plugins, and full RPC API.

## What Does X1-Forge Do?

- Votes on blocks and participates in consensus
- Earns staking rewards
- Runs efficiently on 64GB RAM systems
- Stripped of: MEV, Geyser, full RPC API

**Don't want to stake?** Use [X1-Aether](https://github.com/fortiblox/X1-Aether) for verification-only mode.

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 8 cores | 16 cores |
| RAM | 64 GB | 128 GB |
| Storage | 400 GB NVMe | 1 TB NVMe |
| Network | 100 Mbps | 1 Gbps |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 |

## Quick Install

```bash
curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
```

The installer will:
1. Install Rust and dependencies
2. Build from Tachyon source (x1-labs/tachyon)
3. Generate identity and vote account keypairs
4. Apply kernel optimizations
5. Configure stripped-down systemd service

## After Installation

1. **Fund your identity wallet** with XNT for vote transaction fees
2. **Create vote account on-chain**:
   ```bash
   solana create-vote-account ~/.config/x1-forge/vote.json \
     ~/.config/x1-forge/identity.json <WITHDRAWER_PUBKEY> \
     --commission 10 --url https://rpc.mainnet.x1.xyz
   ```
3. **Start the validator**: `sudo systemctl start x1-forge`

## Commands

```bash
# Start validator
sudo systemctl start x1-forge

# Check status
x1-forge status

# View logs
x1-forge logs

# Check sync progress
x1-forge catchup

# Health check
x1-forge health
```

## What's Stripped

Compared to a full validator, X1-Forge removes:

| Feature | Full Validator | X1-Forge |
|---------|---------------|----------|
| MEV/Jito | Yes | **No** |
| Geyser Plugins | Yes | **No** |
| Full RPC API | Yes | **No** |
| Transaction History | Yes | **No** |
| Extended Metadata | Yes | **No** |

This reduces RAM usage from 128GB+ to ~64GB.

## Comparison: X1-Forge vs X1-Aether

| Feature | X1-Forge | X1-Aether |
|---------|----------|-----------|
| Purpose | Vote & earn rewards | Verify chain only |
| RAM Required | 64 GB | 8 GB |
| Earns Rewards | Yes | No |
| Votes | Yes | No |

## Keypair Backup

**Critical**: Back up your keypairs after installation:
- `~/.config/x1-forge/identity.json`
- `~/.config/x1-forge/vote.json`

Loss of these files means loss of your validator identity and vote account.

## License

Apache 2.0
