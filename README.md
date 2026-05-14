# DeFi Protocol Development — Assignment 2

This project implements a comprehensive DeFi protocol suite including an Automated Market Maker (AMM), a lending/borrowing protocol, and professional testing infrastructure using Foundry.

## Project Structure

```
├── src/
│   ├── SimpleERC20.sol          # ERC-20 token implementation
│   ├── LPToken.sol              # LP token for AMM liquidity
│   ├── ConstantProductAMM.sol   # Constant product AMM (x*y=k)
│   └── LendingPool.sol          # Lending/borrowing protocol
├── test/
│   ├── SimpleERC20.t.sol        # ERC-20 unit, fuzz, and invariant tests
│   ├── ForkTest.t.sol           # Mainnet fork tests
│   ├── ConstantProductAMM.t.sol # AMM test suite (25+ tests)
│   └── LendingPool.t.sol        # Lending pool test suite (20+ tests)
├── script/                       # Deployment scripts
├── docs/
│   ├── fuzz-vs-unit-testing.md  # Fuzz vs unit testing comparison
│   ├── fork-testing.md          # Fork testing analysis
│   ├── amm-mathematical-analysis.md  # AMM math derivation
│   ├── cicd-documentation.md    # CI/CD pipeline docs
│   └── lending-pool-workflow.html    # Workflow diagram
├── .github/workflows/
│   └── test.yml                 # GitHub Actions CI/CD
└── foundry.toml                 # Foundry configuration
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- (Optional) RPC URL for fork testing

## Quick Start

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Build Contracts

```bash
forge build
```

### Run Tests

```bash
forge test -vvv
```

### Run with Fork Tests

```bash
# Set your RPC URL
export MAINNET_RPC_URL="https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY"

forge test --match-contract ForkTest -vvv
```

### Generate Coverage Report

```bash
forge coverage
```

### Generate Gas Report

```bash
forge test --gas-report -vvv
```

## Contract Overview

### SimpleERC20
Standard ERC-20 token with `mint`, `transfer`, `approve`, and `transferFrom` functions.

### ConstantProductAMM
Implements a Uniswap V2-style AMM:
- **addLiquidity()**: Deposit both tokens, receive LP tokens
- **removeLiquidity()**: Burn LP tokens, receive proportional reserves
- **swap()**: Trade tokens using constant product formula with 0.3% fee
- **getAmountOut()**: Calculate expected output for a given input

### LendingPool
Implements a lending/borrowing protocol:
- **deposit()**: Deposit collateral
- **borrow()**: Borrow against collateral (max 75% LTV)
- **repay()**: Repay borrowed amount
- **withdraw()**: Withdraw collateral (if health factor > 1)
- **liquidate()**: Liquidate undercollateralized positions

## Testing Summary

| Contract | Unit Tests | Fuzz Tests | Invariant Tests | Fork Tests | Total |
|----------|-----------|------------|-----------------|------------|-------|
| SimpleERC20 | 18 | 3 | 3 | — | 24 |
| AMM | 20 | 2 | 1 | — | 23 |
| LendingPool | 20 | — | — | — | 20 |
| Fork Tests | — | — | — | 3 | 3 |

## Documentation

- [Fuzz Testing vs Unit Testing](docs/fuzz-vs-unit-testing.md)
- [Fork Testing Analysis](docs/fork-testing.md)
- [AMM Mathematical Analysis](docs/amm-mathematical-analysis.md)
- [CI/CD Pipeline Documentation](docs/cicd-documentation.md)
- [Lending Pool Workflow Diagram](docs/lending-pool-workflow.html)

## CI/CD Pipeline

The project includes a GitHub Actions pipeline that:
1. Installs Foundry
2. Compiles contracts
3. Runs all tests
4. Generates gas reports
5. Measures test coverage
6. Runs Slither static analysis

## Author

Blockchain Technologies 2 — Assignment 2 Submission
