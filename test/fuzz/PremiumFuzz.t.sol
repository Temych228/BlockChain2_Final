// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PremiumMath} from "../../src/libraries/PremiumMath.sol";

/// @title PremiumFuzz — Fuzz tests for PremiumMath library
/// @notice Validates Yul/Solidity equivalence and premium monotonicity.
contract PremiumFuzzTest is Test {
    /// @notice Yul and Solidity implementations must always return identical results.
    function testFuzz_PremiumEquivalence(uint64 coverage, uint64 util, uint64 risk) public pure {
        uint256 yulResult = PremiumMath.calculatePremium(coverage, util, risk);
        uint256 solResult = PremiumMath.calculatePremiumSolidity(coverage, util, risk);
        assertEq(yulResult, solResult, "Yul and Solidity must match");
    }

    /// @notice Higher coverage should produce >= premium (monotonicity).
    function testFuzz_PremiumMonotonicity(uint64 coverage1, uint64 coverage2) public pure {
        uint256 c1 = bound(coverage1, 1, type(uint64).max - 1);
        uint256 c2 = bound(coverage2, c1 + 1, type(uint64).max);

        uint256 premium1 = PremiumMath.calculatePremium(c1, 5e17, 1e18);
        uint256 premium2 = PremiumMath.calculatePremium(c2, 5e17, 1e18);
        assertGe(premium2, premium1, "Higher coverage must yield higher or equal premium");
    }

    /// @notice Higher utilization should produce >= premium.
    function testFuzz_PremiumIncreasesWithUtilization(uint64 util1, uint64 util2) public pure {
        uint256 u1 = bound(util1, 1, 1e18 - 1);
        uint256 u2 = bound(util2, u1 + 1, 1e18);

        uint256 p1 = PremiumMath.calculatePremium(10_000e6, u1, 1e18);
        uint256 p2 = PremiumMath.calculatePremium(10_000e6, u2, 1e18);
        assertGe(p2, p1, "Higher utilization must yield higher or equal premium");
    }

    /// @notice Zero coverage always produces zero premium regardless of other inputs.
    function testFuzz_ZeroCoverageAlwaysZero(uint64 util, uint64 risk) public pure {
        assertEq(PremiumMath.calculatePremium(0, util, risk), 0, "Zero coverage = zero premium");
    }
}
