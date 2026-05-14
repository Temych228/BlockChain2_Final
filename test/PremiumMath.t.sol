// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PremiumMath} from "../src/libraries/PremiumMath.sol";

contract PremiumMathWrapper {
    function yul(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PremiumMath.calculatePremium(a, b, c);
    }

    function sol(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return PremiumMath.calculatePremiumSolidity(a, b, c);
    }
}

contract PremiumMathTest is Test {
    PremiumMathWrapper internal wrapper;

    function setUp() public {
        wrapper = new PremiumMathWrapper();
    }

    function test_BasicPremiumCalculation() public view {
        // 10,000 USDC coverage, 50% utilization, 1x risk
        uint256 premium = PremiumMath.calculatePremium(10_000e6, 5e17, 1e18);
        // (10_000e6 * 5e17) / 1e18 = 5_000e6, then * 1e18 / 1e18 = 5_000e6
        assertEq(premium, 5000e6);
    }

    function test_ZeroInputs() public view {
        assertEq(PremiumMath.calculatePremium(0, 5e17, 1e18), 0);
        assertEq(PremiumMath.calculatePremium(10_000e6, 0, 1e18), 0);
        assertEq(PremiumMath.calculatePremium(10_000e6, 5e17, 0), 0);
    }

    function test_FullUtilization() public view {
        // 1000 USDC, 100% utilization, 2x risk
        uint256 premium = PremiumMath.calculatePremium(1000e6, 1e18, 2e18);
        assertEq(premium, 2000e6);
    }

    function testGas_PremiumYulVsSolidity() public {
        uint256 coverage = 10_000e6;
        uint256 util = 5e17;
        uint256 risk = 15e17;

        // Warm both code paths (pay cold access cost)
        wrapper.yul(coverage, util, risk);
        wrapper.sol(coverage, util, risk);

        // Now measure on warm calls
        uint256 gasYul = gasleft();
        wrapper.yul(coverage, util, risk);
        gasYul = gasYul - gasleft();

        uint256 gasSol = gasleft();
        wrapper.sol(coverage, util, risk);
        gasSol = gasSol - gasleft();

        emit log_named_uint("Yul gas", gasYul);
        emit log_named_uint("Solidity gas", gasSol);

        // Both should produce identical results — the key requirement.
        // Gas difference may be negligible with optimizer; we log for documentation.
        assertEq(
            PremiumMath.calculatePremium(coverage, util, risk),
            PremiumMath.calculatePremiumSolidity(coverage, util, risk)
        );
    }

    function testFuzz_PremiumEquivalence(uint256 a, uint256 b, uint256 c) public view {
        // Bound to avoid overflow in intermediate multiplication
        a = bound(a, 1, 1e18);
        b = bound(b, 1, 1e18);
        c = bound(c, 1, 1e18);

        uint256 yulResult = PremiumMath.calculatePremium(a, b, c);
        uint256 solResult = PremiumMath.calculatePremiumSolidity(a, b, c);
        assertEq(yulResult, solResult, "Yul and Solidity must return identical results");
    }
}
