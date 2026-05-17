// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title CollateralFuzz — Fuzz tests for CollateralManager
/// @notice Validates health factor consistency and liquidation threshold invariants.
contract CollateralFuzzTest is Test {
    CollateralManager public cm;
    MockERC20 public usdc;

    address admin = makeAddr("admin");
    address pool = makeAddr("pool");
    address alice = makeAddr("alice");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        cm.grantRole(cm.POOL_ROLE(), pool);
        vm.stopPrank();

        usdc.mint(alice, 100_000_000e6);
        vm.prank(alice);
        usdc.approve(address(cm), type(uint256).max);
    }

    /// @notice Health factor formula: hf = collateral * BASIS_POINTS / exposure.
    ///         Verifying the formula matches for arbitrary valid inputs.
    function testFuzz_HealthFactorConsistency(uint96 collateral, uint96 exposure) public {
        collateral = uint96(bound(collateral, 1e6, 50_000_000e6));

        vm.prank(alice);
        cm.depositCollateral(collateral);

        uint256 maxExposure = (uint256(collateral) * 7500) / 10_000;
        if (maxExposure == 0) return;
        exposure = uint96(bound(exposure, 1, maxExposure));

        vm.prank(pool);
        cm.increaseExposure(alice, exposure);

        uint256 expectedHF = (uint256(collateral) * 10_000) / uint256(exposure);
        assertEq(cm.healthFactor(alice), expectedHF, "Health factor should match formula");
    }

    /// @notice Can only liquidate when actually unhealthy.
    ///         If HF >= LIQUIDATION_THRESHOLD, liquidate() must revert.
    function testFuzz_LiquidationOnlyWhenUnhealthy(uint96 collateral, uint96 exposure) public {
        collateral = uint96(bound(collateral, 1e6, 50_000_000e6));

        vm.prank(alice);
        cm.depositCollateral(collateral);

        uint256 maxExposure = (uint256(collateral) * 7500) / 10_000;
        if (maxExposure == 0) return;
        exposure = uint96(bound(exposure, 1, maxExposure));

        vm.prank(pool);
        cm.increaseExposure(alice, exposure);

        uint256 hf = cm.healthFactor(alice);

        if (hf >= cm.LIQUIDATION_THRESHOLD()) {
            assertFalse(cm.isLiquidatable(alice), "Should NOT be liquidatable when HF >= threshold");
            vm.expectRevert(CollateralManager.NotLiquidatable.selector);
            cm.liquidate(alice, liquidator);
        } else {
            assertTrue(cm.isLiquidatable(alice), "Should be liquidatable when HF < threshold");
        }
    }

    /// @notice Utilization rate is always <= 1e18 (100%) when exposure is within MAX_LTV.
    function testFuzz_UtilizationRateBounded(uint96 collateral, uint96 exposure) public {
        collateral = uint96(bound(collateral, 1e6, 50_000_000e6));

        vm.prank(alice);
        cm.depositCollateral(collateral);

        uint256 maxExposure = (uint256(collateral) * 7500) / 10_000;
        if (maxExposure == 0) return;
        exposure = uint96(bound(exposure, 1, maxExposure));

        vm.prank(pool);
        cm.increaseExposure(alice, exposure);

        assertLe(cm.utilizationRate(), 1e18, "Utilization should not exceed 100%");
    }
}
