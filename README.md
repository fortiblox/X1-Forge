# X1-Forge

**The Backbone of the X1 Network**

A forge is where raw materials become something greater—where heat, pressure, and skill combine to create strength. X1-Forge validators are the backbone of the X1 network: actively participating in consensus, casting votes, and earning rewards for securing the chain.

While [X1-Aether](https://github.com/fortiblox/X1-Aether) nodes silently observe, Forge validators step into the fire. They don't just verify—they *decide*. Every vote they cast helps the network reach consensus and move forward.

X1-Forge runs an optimized Tachyon validator stripped of MEV, Geyser plugins, and full RPC overhead—purpose-built for validators who want to stake, vote, and earn.

**Just want to verify without staking?** Use [X1-Aether](https://github.com/fortiblox/X1-Aether) for lightweight verification (8GB RAM).

## Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 8 cores | 16 cores |
| RAM | 64 GB | 128 GB |
| Storage | 400 GB NVMe | 1 TB NVMe |
| Network | 100 Mbps | 1 Gbps |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 |

**Additional requirements:**
- Root/sudo access
- Open ports: 8000-8020 (UDP/TCP), 8899 (RPC)

## Installation

```bash
curl -sSfL https://raw.githubusercontent.com/fortiblox/X1-Forge/main/install.sh | bash
```

The installer will:
1. Check system meets requirements
2. Install dependencies (build tools, Rust, Solana CLI)
3. Build Tachyon validator from source (~15-30 minutes)
4. Generate identity and vote keypair files
5. Apply kernel optimizations
6. Install systemd service
7. Create the `x1-forge` CLI wrapper

**File locations:**
- Binary: `/opt/x1-forge/bin/x1-forge`
- Keypairs: `~/.config/x1-forge/`
- Data: `/mnt/x1-forge/`
- Logs: `/mnt/x1-forge/forge.log`

---

## CRITICAL: Back Up Your Keypairs

Immediately after installation, back up these files to secure offline storage:

```
~/.config/x1-forge/identity.json   # Your validator identity
~/.config/x1-forge/vote.json       # Your vote account keypair
```

**Loss of these files = loss of your validator.**

Get your public keys:
```bash
solana-keygen pubkey ~/.config/x1-forge/identity.json
solana-keygen pubkey ~/.config/x1-forge/vote.json
```

---

## Post-Installation Setup

### Step 1: Fund Your Identity Wallet

Your identity wallet pays for vote transaction fees (~0.5 XNT minimum).

```bash
solana transfer <YOUR_IDENTITY_PUBKEY> 1 --url https://rpc.mainnet.x1.xyz
```

Check balance:
```bash
solana balance ~/.config/x1-forge/identity.json --url https://rpc.mainnet.x1.xyz
```

### Step 2: Create Vote Account On-Chain

The installer created keypair files, but you must create the on-chain vote account:

```bash
solana create-vote-account ~/.config/x1-forge/vote.json \
  ~/.config/x1-forge/identity.json \
  <WITHDRAWER_PUBKEY> \
  --commission 10 \
  --url https://rpc.mainnet.x1.xyz
```

**Parameters:**
- `WITHDRAWER_PUBKEY` - Wallet that can withdraw rewards (use a secure cold wallet, not your identity!)
- `--commission 10` - Your commission rate (10 = 10%)

### Step 3: Start the Validator

```bash
sudo systemctl start x1-forge
```

### Step 4: Monitor Sync Progress

Your validator must sync before it can vote (several hours).

```bash
x1-forge catchup    # Sync progress
x1-forge logs       # Live logs
x1-forge health     # Health check
```

---

## Commands

| Command | Description |
|---------|-------------|
| `x1-forge start` | Start validator |
| `x1-forge stop` | Stop validator |
| `x1-forge restart` | Restart validator |
| `x1-forge status` | Show service status |
| `x1-forge logs` | Follow logs |
| `x1-forge catchup` | Show sync progress |
| `x1-forge health` | Health check |

Enable auto-start on boot:
```bash
sudo systemctl enable x1-forge
```

---

## Troubleshooting

### Validator won't start

```bash
journalctl -u x1-forge -n 100 --no-pager
```

**Common issues:**
- **"Vote account not found"** - Create on-chain vote account (Step 2)
- **"Insufficient funds"** - Fund identity wallet (Step 1)
- **Port conflict** - Check with `sudo lsof -i :8899`

### Validator not voting

1. Check sync status: `x1-forge catchup`
2. Verify vote account exists: `solana vote-account ~/.config/x1-forge/vote.json --url https://rpc.mainnet.x1.xyz`
3. Check identity has funds: `solana balance ~/.config/x1-forge/identity.json --url https://rpc.mainnet.x1.xyz`

### Ledger corruption

```bash
sudo systemctl stop x1-forge
rm -rf /mnt/x1-forge/ledger/*
sudo systemctl start x1-forge
```

---

## What's Stripped

| Feature | Full Validator | X1-Forge |
|---------|---------------|----------|
| MEV/Jito | Yes | **No** |
| Geyser Plugins | Yes | **No** |
| Full RPC API | Yes | **No** |
| Transaction History | Yes | **No** |

This reduces RAM from 128GB+ to ~64GB.

---

## Staking to Your Validator

Once synced and voting:

```bash
solana create-stake-account stake.json <AMOUNT> --url https://rpc.mainnet.x1.xyz
solana delegate-stake stake.json <YOUR_VOTE_PUBKEY> --url https://rpc.mainnet.x1.xyz
```

---

## Forge vs Aether: Choose Your Role

| | X1-Forge | X1-Aether |
|---------|----------|-----------|
| **Role** | Active Validator | Silent Observer |
| **Purpose** | Vote on blocks & earn rewards | Verify the chain independently |
| **RAM Required** | 64 GB | 8 GB |
| **Earns Rewards** | Yes | No |
| **Participates in Consensus** | Yes | No |

*Forge decides. Aether watches. Both strengthen the network.*

## License

Apache 2.0
