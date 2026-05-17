# Decentralized Insurance Pool Protocol (InsureDAO)

> Blockchain Technologies 2 — Final Project | Option E

## Overview

InsureDAO is a fully on-chain decentralized insurance protocol built on Arbitrum Sepolia. It enables users to purchase insurance policies against stablecoin depeg events, liquidation risks, and smart contract exploits, while allowing underwriters to earn yield by providing collateral to the risk pool.

The protocol features a complete governance system powered by the IDAO token, where token holders can propose, vote on, and execute changes to protocol parameters and treasury operations through a TimelockController. All contracts are written in Solidity 0.8.24, tested with 173+ Foundry tests (96.1% line coverage), and designed for L2 deployment with EIP-6372 timestamp-based voting.

## Architecture

The protocol consists of interconnected smart contracts following a modular design:

- **InsurancePool** (UUPS Proxy) — Core orchestrator managing policy lifecycle
- **UnderwriterVault** (ERC-4626) — Tokenized vault for underwriter deposits + premium yield
- **CollateralManager** — Lending-pool-style collateral with LTV, health factor, and liquidation
- **PolicyNFT** (ERC-1155) — Semi-fungible tokens representing insurance policies
- **GovernanceToken** (ERC-20 + Votes) — IDAO token with delegation and permit
- **InsuranceGovernor** — Full OpenZeppelin Governor stack with timelock
- **InsuranceTreasury** — Protocol fee treasury controlled by governance
- **PremiumMath** — Premium calculation library with inline Yul assembly

See [docs/architecture.md](docs/architecture.md) for detailed diagrams and design decisions.

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Arbiscan |
|---|---|---|
| InsurancePool (Proxy) | `0xF293eD1ABd74D70A012c69b15f22C20Df4c8858C` | [View](https://sepolia.arbiscan.io/address/0xF293eD1ABd74D70A012c69b15f22C20Df4c8858C) |
| UnderwriterVault | `0xB0Cb5ECf100d8668A250118e64D6DA7f728E4865` | [View](https://sepolia.arbiscan.io/address/0xB0Cb5ECf100d8668A250118e64D6DA7f728E4865) |
| CollateralManager | `0xaAa36a7DEb22fdd9e3A5613f378405655cACc7bA` | [View](https://sepolia.arbiscan.io/address/0xaAa36a7DEb22fdd9e3A5613f378405655cACc7bA) |
| PolicyNFT | `0xa3Fc2415c383c58f5f27FcE5f1d26Cc54Dc9cEa6` | [View](https://sepolia.arbiscan.io/address/0xa3Fc2415c383c58f5f27FcE5f1d26Cc54Dc9cEa6) |
| GovernanceToken (IDAO) | `0xb06eCBf6dC4Ca68716b400bfC1Aacbae0d7e487f` | [View](https://sepolia.arbiscan.io/address/0xb06eCBf6dC4Ca68716b400bfC1Aacbae0d7e487f) |
| InsuranceGovernor | `0xD01F3b6e16828628746e0C6Be4258B81572ba549` | [View](https://sepolia.arbiscan.io/address/0xD01F3b6e16828628746e0C6Be4258B81572ba549) |
| TimelockController | `0x47089891c1a1e62A0bD880949fEa592056237970` | [View](https://sepolia.arbiscan.io/address/0x47089891c1a1e62A0bD880949fEa592056237970) |
| InsuranceTreasury | `0x032E146D35a5D643A18Deac4C3166592aCf1dB70` | [View](https://sepolia.arbiscan.io/address/0x032E146D35a5D643A18Deac4C3166592aCf1dB70) |
| MockUSDC | `0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C` | [View](https://sepolia.arbiscan.io/address/0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C) |
| PolicyFactory | `0xDcDd4c95a9c16C259E1f1c5824F65D0A32e89714` | [View](https://sepolia.arbiscan.io/address/0xDcDd4c95a9c16C259E1f1c5824F65D0A32e89714) |

## Quick Start

```bash
# Clone and install
git clone <repo-url>
cd BlockChain2_Final
forge install

# Build
forge build

# Run tests
forge test

# Run tests with verbosity
forge test -vvv
```

## Environment Setup

```bash
cp .env.example .env
# Fill in your values:
#   PRIVATE_KEY — deployer wallet private key
#   ARBITRUM_SEPOLIA_RPC — RPC endpoint
#   ARBISCAN_API_KEY — for contract verification
```

## Deployment

```bash
# Deploy all contracts to Arbitrum Sepolia
make deploy-arbitrum

# Verify deployment configuration
make verify-deployment
```

## Frontend

### Quick Start (for reviewers/testers)

The contracts are already deployed to Arbitrum Sepolia. To test the frontend:

```bash
# 1. Install frontend dependencies
cd frontend
npm install

# 2. Start the dev server
npm run dev
# Open http://localhost:5174
```

### Getting Test Tokens

After connecting your MetaMask wallet (on Arbitrum Sepolia network), you need USDC and IDAO tokens.
Run this from the project root (replace `0xYOUR_WALLET` with your MetaMask address):

```bash
make seed-tokens WALLET=0xYOUR_WALLET_ADDRESS
```

This mints **10,000 USDC** and **10,000 IDAO** to your wallet. You'll see balances in the navbar after refreshing.

> **Note:** The deployer key (`0xac09...`) used by `seed-tokens` must have Arbitrum Sepolia ETH.
> Fund it at a faucet if needed: deployer address is `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`.

### Testing the Frontend

1. **Governance page** — Click "Delegate to Myself" to activate voting power
2. **Underwrite page** — Enter `1000` USDC → Approve → Deposit Collateral
3. **Insure page** — Policy Type `0`, Coverage `100` USDC, Duration `30` days → Purchase Policy
4. **Dashboard** — See your position update in real-time

### Frontend Features
- MetaMask + WalletConnect integration
- Purchase insurance policies (USDC approval + policy purchase)
- Deposit collateral as underwriter
- Governance: view proposals, cast votes, delegate tokens
- Real-time protocol stats via The Graph subgraph
- Auto-refreshing balances (every 4 seconds)
- Buffered gas pricing for Arbitrum Sepolia compatibility

## Subgraph

```bash
cd subgraph
npm install
npm run codegen
npm run build
npm run deploy
```

Indexed entities: Policy, UnderwriterPosition, Claim, GovernanceProposal, ProtocolStats.
See [subgraph/queries.graphql](subgraph/queries.graphql) for 5 documented GraphQL queries.

## Test Suite

```bash
# All tests (unit + fuzz + invariant)
forge test

# Gas benchmarks
make gas-report

# Coverage report
make coverage
# See reports/coverage.md
```

| Category | Count | Target |
|---|---|---|
| Unit tests | 129 | ≥50 |
| Fuzz tests | 21 | ≥10 |
| Invariant tests | 5 | ≥5 |
| Fork tests | 7 | ≥3 |
| **Total** | **173+** | **≥80** |
| **Line coverage** | **96.1%** | **≥90%** |

## Security

See [docs/audit-report.md](docs/audit-report.md) for the internal security audit report.

Key security patterns:
- CEI (Checks-Effects-Interactions) in all state-changing functions
- `ReentrancyGuard` on all external entry points
- `SafeERC20` for all token interactions
- Custom errors (no string reverts)
- Role-based access control (`AccessControl` / `Ownable2Step`)
- Emergency pause via `Pausable`
- ERC-4626 rounding convention (deposit rounds DOWN, withdraw rounds UP)
- UUPS upgrade restricted to `DEFAULT_ADMIN_ROLE`
- Storage gap (`__gap[43]`) for upgrade safety

## Documentation

| Document | Description |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Architecture diagrams, storage layout, ADRs |
| [docs/audit-report.md](docs/audit-report.md) | Security audit with 9 findings |
| [docs/gas-optimization.md](docs/gas-optimization.md) | Gas benchmarks and optimization analysis |
| [reports/coverage.md](reports/coverage.md) | Test coverage report |
| [reports/gas-comparison.md](reports/gas-comparison.md) | L1 vs L2 gas comparison |

## Project Structure

```
BlockChain2_Final/
├── src/                          # Production contracts
│   ├── InsurancePool.sol         # Core UUPS-upgradeable pool
│   ├── InsurancePoolV2.sol       # V2 upgrade
│   ├── UnderwriterVault.sol      # ERC-4626 vault
│   ├── CollateralManager.sol     # Lending-pool collateral
│   ├── PolicyNFT.sol             # ERC-1155 policy tokens
│   ├── GovernanceToken.sol       # IDAO governance token
│   ├── PolicyFactory.sol         # CREATE/CREATE2 factory
│   ├── governance/               # Governor + Treasury
│   ├── libraries/                # PremiumMath (Yul)
│   └── interfaces/               # IOracle, ICollateralManager, etc.
├── test/                         # Test suite
│   ├── unit/                     # Extended unit tests
│   ├── fuzz/                     # Fuzz tests
│   ├── invariant/                # Invariant tests + handler
│   ├── fork/                     # Fork tests (Arbitrum)
│   ├── governance/               # Governance lifecycle tests
│   └── gas/                      # Gas benchmark tests
├── script/                       # Deployment scripts
├── subgraph/                     # The Graph subgraph
├── frontend/                     # React dApp
├── docs/                         # Documentation
└── reports/                      # Coverage + gas reports
```

## Tech Stack

- **Smart Contracts:** Solidity 0.8.24, OpenZeppelin v5
- **Framework:** Foundry (forge, cast, anvil)
- **L2:** Arbitrum Sepolia
- **Frontend:** React 18, Vite, Wagmi v2, Viem, TanStack Query
- **Indexing:** The Graph (AssemblyScript mappings)
- **Testing:** Foundry (unit, fuzz, invariant, fork)
