# X1-Forge

**Efficient Voting Validator for X1 Blockchain**

X1-Forge is a stripped-down, optimized validator designed for voting and earning staking rewards on lower-spec hardware.

## Features

- **Lightweight**: Runs on 64GB RAM (vs 128GB+ for full validators)
- **Voting-focused**: Stripped of RPC, Geyser, MEV for efficiency
- **Turnkey**: One-command install with auto-tuning
- **Easy upgrades**: Track x1labs releases with simple update command

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 8 cores | 16 cores |
| RAM | 64 GB | 128 GB |
| Storage | 500 GB NVMe | 1 TB NVMe |
| Network | 100 Mbps | 1 Gbps |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 |

## Quick Install

```bash
curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
```

## What Gets Installed

- Tachyon validator binary (optimized build)
- Systemd service (`x1-forge.service`)
- Auto-tuned configuration for your hardware
- Keypair generation (identity + vote account)
- Snapshot download automation

## Commands

```bash
# Check status
sudo systemctl status x1-forge

# View logs
journalctl -u x1-forge -f

# Check for updates
x1-forge update --check

# Perform upgrade
x1-forge update

# Rollback if needed
x1-forge rollback

# Health check
x1-forge health
```

## Configuration

Config file: `~/.config/x1-forge/config.toml`

```toml
[network]
cluster = "mainnet"

[paths]
ledger = "/mnt/x1-forge/ledger"
identity = "~/.config/solana/forge-identity.json"
vote_account = "~/.config/solana/forge-vote.json"

[performance]
# Auto-tuned based on your hardware
ledger_size = 10000000
snapshot_interval = 10000
```

## Directory Structure

```
~/.config/x1-forge/
├── config.toml          # Main configuration
├── forge-identity.json  # Validator identity keypair
└── forge-vote.json      # Vote account keypair

/mnt/x1-forge/
└── ledger/              # Blockchain data
```

## Comparison: X1-Forge vs Full Validator

| Feature | Full Validator | X1-Forge |
|---------|---------------|----------|
| RAM Required | 128-256 GB | 64 GB |
| Disk Required | 2 TB+ | 500 GB |
| Full RPC API | Yes | No (health only) |
| Geyser Plugins | Yes | No |
| MEV Extraction | Yes | No |
| Voting | Yes | Yes |
| Staking Rewards | Yes | Yes |

## Upgrading

X1-Forge tracks upstream x1labs/tachyon releases:

```bash
# Check available updates
x1-forge update --check

# Upgrade (with automatic backup)
x1-forge update

# Rollback if issues
x1-forge rollback
```

## Troubleshooting

### Validator not voting
```bash
# Check health
x1-forge health

# Check logs for errors
journalctl -u x1-forge -n 100 --no-pager
```

### Low memory
```bash
# Check memory usage
free -h

# Restart with fresh state
sudo systemctl restart x1-forge
```

### Sync issues
```bash
# Check slot progress
x1-forge status

# Re-download snapshot if needed
x1-forge snapshot --download
```

## Support

- Issues: https://github.com/fortiblox/X1-Forge/issues
- X1 Discord: https://discord.gg/x1blockchain

## License

Apache 2.0

## Credits

Based on [x1labs/tachyon](https://github.com/x1-labs/tachyon), optimized for efficient voting.
