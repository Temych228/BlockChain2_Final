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

| Contract | Address | Verified |
|---|---|---|
| InsurancePool (Proxy) | `TBD` | - |
| UnderwriterVault | `TBD` | - |
| CollateralManager | `TBD` | - |
| PolicyNFT | `TBD` | - |
| GovernanceToken (IDAO) | `TBD` | - |
| InsuranceGovernor | `TBD` | - |
| TimelockController | `TBD` | - |
| InsuranceTreasury | `TBD` | - |

> Deploy with `make deploy-arbitrum` and fill in addresses after deployment.

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

```bash
cd frontend
npm install
npm run dev
# Open http://localhost:5173
```

Features:
- MetaMask + WalletConnect integration
- Purchase insurance policies (USDC approval + policy purchase)
- Deposit collateral as underwriter
- Governance: view proposals, cast votes, delegate tokens
- Real-time protocol stats via The Graph subgraph

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
