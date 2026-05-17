# Gas Comparison: Arbitrum Sepolia vs Ethereum Mainnet

## Methodology

Gas measurements obtained via Foundry's `gasleft()` in `test/gas/GasSnapshot.t.sol`.
L1 costs estimated at 30 gwei gas price (Ethereum mainnet average).
L2 costs estimated at 0.1 gwei gas price (Arbitrum Sepolia).

Arbitrum uses a two-component fee model:
- **L2 execution fee**: computation on Arbitrum (measured below)
- **L1 data posting fee**: calldata compressed and posted to Ethereum L1

The L1 data posting fee is NOT captured by `gasleft()` and must be measured
on-chain via `ArbGasInfo.getCurrentTxL1GasFees()`.

## Gas Results

| # | Operation | L1 Gas | L1 Cost (@30 gwei) | L2 Gas | L2 Cost (@0.1 gwei) | Savings |
|---|-----------|--------|---------------------|--------|----------------------|---------|
| 1 | `GovernanceToken.delegate()` | 79,142 | 0.00237 ETH | TBD | TBD | TBD |
| 2 | `UnderwriterVault.deposit(1000e6)` | 64,803 | 0.00194 ETH | TBD | TBD | TBD |
| 3 | `UnderwriterVault.withdraw(1000e6)` | 18,015 | 0.00054 ETH | TBD | TBD | TBD |
| 4 | `InsurancePool.purchasePolicy()` | 280,130 | 0.00840 ETH | TBD | TBD | TBD |
| 5 | `InsurancePool.processClaim()` | 64,354 | 0.00193 ETH | TBD | TBD | TBD |
| 6 | `CollateralManager.liquidate()` | 36,237 | 0.00109 ETH | TBD | TBD | TBD |

## How to Fill This Table

1. **L1 Gas**: Run `forge test --match-contract GasSnapshot -vv` locally (defaults to L1 EVM).
   Copy the gas values from console output.

2. **L1 Cost**: `gas × 30 gwei × ETH_price`.

3. **L2 Gas**: Deploy contracts to Arbitrum Sepolia, execute same operations via cast,
   check transaction receipts for `gasUsed`.

4. **L2 Cost**: `gas × 0.1 gwei × ETH_price + L1_data_fee`.

5. **Savings**: `(L1_cost - L2_cost) / L1_cost × 100%`.

## Commands

```bash
# Local gas snapshot (L1 simulation)
forge test --match-contract GasSnapshot -vv

# Generate Foundry gas snapshot file
forge snapshot --snap .gas-snapshot

# Deploy to Arbitrum Sepolia and measure on-chain
forge script script/DeployAll.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast -vvvv
```

## Notes

- Arbitrum Nitro compresses calldata before posting to L1, so actual L1 data fees
  are lower than raw calldata size would suggest.
- L2 execution gas is typically similar to L1 execution gas for the same operation,
  but the gas price is ~300x cheaper on Arbitrum.
- `delegate()` is relatively cheap (single storage write + checkpoint), while
  `purchasePolicy()` is expensive (multiple external calls, state writes, NFT mint).
- The most expensive operation is `processClaim()` due to vault withdrawal, token
  transfers, exposure decrease, and NFT burn in a single transaction.
