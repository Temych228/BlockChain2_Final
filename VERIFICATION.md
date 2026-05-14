# Project Verification Guide

## Quick Verification Steps

### 1. Verify Project Structure

```bash
# Check all required files exist
ls -la src/SimpleERC20.sol
ls -la src/LPToken.sol
ls -la src/ConstantProductAMM.sol
ls -la src/LendingPool.sol
ls -la test/SimpleERC20.t.sol
ls -la test/ConstantProductAMM.t.sol
ls -la test/LendingPool.t.sol
ls -la test/ForkTest.t.sol
ls -la .github/workflows/test.yml
ls -la docs/
```

### 2. Build and Test

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
git submodule update --init --recursive

# Build contracts
forge build --sizes

# Run all tests
forge test -vvv

# Generate coverage
forge coverage --report summary

# Generate gas report
forge test --gas-report -vvv
```

### 3. Run Fork Tests (Optional)

```bash
# Set your RPC URL (get one from Alchemy, Infura, or similar)
export MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# Run fork tests
forge test --match-contract ForkTest -vvv
```

### 4. Verify Test Counts

```bash
# Count tests in each file
grep -c "function test" test/SimpleERC20.t.sol      # Should be 24+
grep -c "function test" test/ConstantProductAMM.t.sol # Should be 23+
grep -c "function test" test/LendingPool.t.sol        # Should be 20+
grep -c "function test" test/ForkTest.t.sol           # Should be 3+
```

## Deliverables Checklist

### Part 1 — Advanced Testing with Foundry
- [x] Foundry project with src/, test/, script/ directories
- [x] SimpleERC20 token contract
- [x] 18+ unit tests for ERC-20 (mint, transfer, approve, transferFrom, edge cases)
- [x] 3 fuzz tests for transfer function
- [x] 3 invariant tests (total supply unchanged, no address exceeds total, sum of balances)
- [x] Coverage report (run `forge coverage`)
- [x] Fuzz vs unit testing explanation (`docs/fuzz-vs-unit-testing.md`)
- [x] Fork test for USDC total supply
- [x] Fork test for Uniswap V2 swap simulation
- [x] Fork testing explanation (`docs/fork-testing.md`)

### Part 2 — AMM Development
- [x] ConstantProductAMM.sol with x*y=k formula
- [x] LPToken.sol for liquidity provider shares
- [x] addLiquidity() with proportional deposits
- [x] removeLiquidity() with LP token burning
- [x] swap() with 0.3% fee
- [x] getAmountOut() calculation
- [x] Event emissions (LiquidityAdded, LiquidityRemoved, Swap)
- [x] Slippage protection (minAmountOut parameter)
- [x] 23+ test cases covering all requirements
- [x] Gas report (run `forge test --gas-report`)
- [x] Mathematical analysis document (`docs/amm-mathematical-analysis.md`)

### Part 3 — Lending Protocol
- [x] LendingPool.sol with all functions
- [x] deposit(), borrow(), repay(), withdraw(), liquidate()
- [x] 75% LTV limit enforcement
- [x] Health factor calculation
- [x] Linear interest rate model
- [x] 20+ test cases
- [x] Gas report
- [x] Workflow diagram (`docs/lending-pool-workflow.html`)

### Part 4 — CI/CD Pipeline
- [x] `.github/workflows/test.yml` with all stages
- [x] Foundry installation step
- [x] Compilation step
- [x] Test execution
- [x] Gas report generation
- [x] Slither analysis step
- [x] Pipeline documentation (`docs/cicd-documentation.md`)

## Expected Test Output

When running `forge test -vvv`, you should see:

```
Ran 67 tests for test/SimpleERC20.t.sol:SimpleERC20Test
[PASS] test_Mint (gas: ...)
[PASS] test_Transfer (gas: ...)
...
[PASS] testFuzz_Trans (runs: 256, μ: ..., ~: ...)
...
[PASS] testInvariant_TotalSupplyUnchangedAfterTransfer (gas: ...)

Ran 23 tests for test/ConstantProductAMM.t.sol:AMMTest
[PASS] test_AddLiquidityFirstProvider (gas: ...)
...
[PASS] testFuzz_Swap (runs: 256, μ: ..., ~: ...)

Ran 20 tests for test/LendingPool.t.sol:LendingPoolTest
[PASS] test_Deposit (gas: ...)
...

Ran 3 tests for test/ForkTest.t.sol:ForkTest
[PASS] test_ReadUSDC_TotalSupply (gas: ...)
...

Suite result: ok. 67 passed; 0 failed; ...
```

## Notes

- Fork tests will skip if `MAINNET_RPC_URL` is not set
- All contracts use Solidity 0.8.20
- The project uses Foundry's built-in testing framework
- Gas reports are generated automatically with `--gas-report` flag
