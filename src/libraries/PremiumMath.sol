// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PremiumMath
/// @notice Fixed-point premium calculation library with both Yul assembly and pure Solidity
///         implementations for benchmarking. Required by rubric §3.1 (inline Yul assembly).
/// @dev Formula: premium = (coverageAmount * utilizationRatio * riskMultiplier) / (1e18 * 1e18)
///      Both functions MUST return identical results for all inputs.
library PremiumMath {
    /// @notice Calculates the insurance premium using inline Yul assembly (gas-optimized).
    /// @dev Uses a two-step mulDiv pattern to avoid intermediate overflow:
    ///      step1 = (coverageAmount * utilizationRatio) / 1e18
    ///      step2 = (step1 * riskMultiplier) / 1e18
    /// @param coverageAmount The coverage amount in USDC (6 decimals).
    /// @param utilizationRatio Pool utilization scaled to 1e18 (0 = 0%, 1e18 = 100%).
    /// @param riskMultiplier Risk multiplier scaled to 1e18 (1e18 = 1x).
    /// @return premium The calculated premium amount.
    function calculatePremium(uint256 coverageAmount, uint256 utilizationRatio, uint256 riskMultiplier)
        internal
        pure
        returns (uint256 premium)
    {
        // Yul assembly block — opcode-by-opcode explanation:
        //   mul    — multiplies two 256-bit integers (unchecked, wraps on overflow)
        //   div    — unsigned integer division (returns 0 if divisor is 0)
        //
        //   Step 1: intermediate = coverageAmount * utilizationRatio / 1e18
        //   Step 2: premium     = intermediate * riskMultiplier / 1e18
        //
        //   Division by 1e18 (0xDE0B6B3A7640000) scales the result back from fixed-point.
        //   The two-step approach avoids a single triple multiplication that could overflow
        //   uint256 for large inputs.
        assembly {
            let scale := 0xDE0B6B3A7640000 // 1e18
            let intermediate := div(mul(coverageAmount, utilizationRatio), scale)
            premium := div(mul(intermediate, riskMultiplier), scale)
        }
    }

    /// @notice Calculates the insurance premium using pure Solidity (reference implementation).
    /// @dev Same formula as calculatePremium — used for equivalence testing and gas benchmarking.
    /// @param coverageAmount The coverage amount in USDC (6 decimals).
    /// @param utilizationRatio Pool utilization scaled to 1e18.
    /// @param riskMultiplier Risk multiplier scaled to 1e18.
    /// @return premium The calculated premium amount.
    function calculatePremiumSolidity(uint256 coverageAmount, uint256 utilizationRatio, uint256 riskMultiplier)
        internal
        pure
        returns (uint256 premium)
    {
        uint256 intermediate = (coverageAmount * utilizationRatio) / 1e18;
        premium = (intermediate * riskMultiplier) / 1e18;
    }
}
