# Decentralized Insurance Pool Protocol

> Blockchain Technologies 2 — Final Project | Option E

## Overview

A decentralized insurance pool protocol where underwriters deposit collateral into an ERC-4626 vault to earn premium yield, and policyholders purchase insurance policies represented as ERC-1155 NFTs. The protocol uses Chainlink oracles for triggering insurance events and is governed by a DAO with an OpenZeppelin Governor stack and a 2-day Timelock.

The protocol features a lending-pool-style collateral system with LTV ratios, health factors, and liquidation mechanics, ensuring the pool remains solvent at all times.

## Architecture

See `docs/architecture.md` for full architecture documentation (C4 diagrams, sequence diagrams, storage layout, ADRs).

## Contracts

| Contract | Description |
|---|---|
| `GovernanceToken` | ERC20Votes + ERC20Permit governance token (IDAO) |
| `PolicyNFT` | ERC-1155 policy tokens (one tokenId per policy type) |
| `PolicyFactory` | CREATE + CREATE2 factory for deploying policy type contracts |
| `UnderwriterVault` | ERC-4626 vault for underwriter collateral and premium yield |
| `CollateralManager` | Lending-pool: LTV, health factor, liquidation |
| `InsurancePool` | UUPS upgradeable core protocol (V1 + V2) |
| `ChainlinkOracleAdapter` | Chainlink price feed with staleness validation |
| `ClaimProcessor` | Automated claim payouts (CEI + ReentrancyGuard) |
| `InsuranceGovernor` | OpenZeppelin Governor (1d delay, 1w period, 4% quorum) |
| `TimelockController` | 2-day delay, controls treasury |
| `PremiumMath` | Yul assembly fixed-point premium calculations |

## Quick Start

```bash
git clone <repo-url>
cd blockchain2-final
forge install
forge build
forge test
```

## Environment Setup

```bash
cp .env.example .env
# Fill in your private key, RPC URL, and API keys
```

## Deployment

```bash
# Deploy to Arbitrum Sepolia
make deploy-arbitrum

# Verify deployment
make verify-deployment
```

## Test Coverage

```bash
make coverage
# See reports/coverage.md
```

## Security

See `docs/audit-report.md` for the internal security audit report.

## Documentation

- Architecture: `docs/architecture.md`
- Audit Report: `docs/audit-report.md`
- Gas Report: `docs/gas-optimization.md`
