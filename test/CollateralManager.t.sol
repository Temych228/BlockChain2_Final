// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract CollateralManagerTest is Test {
    CollateralManager public cm;
    MockERC20 public usdc;

    address public admin;
    address public pool;
    address public alice;
    address public bob;
    address public liquidator;

    function setUp() public {
        admin = makeAddr("admin");
        pool = makeAddr("pool");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        liquidator = makeAddr("liquidator");

        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        cm.grantRole(cm.POOL_ROLE(), pool);
        vm.stopPrank();

        // Fund
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);

        vm.prank(alice);
        usdc.approve(address(cm), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(cm), type(uint256).max);
    }

    // ─── Deposit Collateral
    // ──────────────────────────────────────

    function test_DepositCollateral_UpdatesBalance() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        assertEq(cm.collateralBalances(alice), 10_000e6);
        assertEq(cm.totalCollateral(), 10_000e6);
        assertEq(usdc.balanceOf(address(cm)), 10_000e6);
    }

    function test_DepositCollateral_ZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(CollateralManager.ZeroAmount.selector);
        cm.depositCollateral(0);
    }

    // ─── Withdraw Collateral
    // ─────────────────────────────────────

    function test_WithdrawCollateral_Success() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(alice);
        cm.withdrawCollateral(5000e6);

        assertEq(cm.collateralBalances(alice), 5000e6);
        assertEq(cm.totalCollateral(), 5000e6);
    }

    function test_WithdrawCollateral_HealthFactorBreached_Reverts() public {
        // Deposit 10k, expose 7k (70% LTV within MAX_LTV=75%)
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 7000e6);

        // Withdraw 4100 → 5900 collateral, 7000 exposure → hf = 5900*10000/7000 = 8428 < 8500
        vm.prank(alice);
        vm.expectRevert(CollateralManager.InsufficientHealthFactor.selector);
        cm.withdrawCollateral(4100e6);
    }

    function test_WithdrawCollateral_ExactLTV_Passes() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 5000e6);

        // hf = 10000*10000/5000 = 20000 (200%)
        // After withdraw 1500: hf = 8500*10000/5000 = 17000 (170%) > 8500
        vm.prank(alice);
        cm.withdrawCollateral(1500e6);

        assertEq(cm.collateralBalances(alice), 8500e6);
    }

    function test_WithdrawCollateral_InsufficientBalance_Reverts() public {
        vm.prank(alice);
        cm.depositCollateral(1000e6);

        vm.prank(alice);
        vm.expectRevert(CollateralManager.InsufficientCollateral.selector);
        cm.withdrawCollateral(2000e6);
    }

    // ─── Exposure
    // ────────────────────────────────────────────────

    function test_IncreaseExposure_Success() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        // 75% of 10k = 7500 max exposure
        vm.prank(pool);
        cm.increaseExposure(alice, 7500e6);

        assertEq(cm.coverageExposure(alice), 7500e6);
        assertEq(cm.totalExposure(), 7500e6);
    }

    function test_IncreaseExposure_ExceedsMAXLTV_Reverts() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        vm.expectRevert(CollateralManager.ExposureLimitExceeded.selector);
        cm.increaseExposure(alice, 7501e6);
    }

    function test_IncreaseExposure_OnlyPoolRole() public {
        bytes32 role = cm.POOL_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        cm.increaseExposure(alice, 1000e6);
    }

    function test_DecreaseExposure_Success() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 5000e6);

        vm.prank(pool);
        cm.decreaseExposure(alice, 3000e6);

        assertEq(cm.coverageExposure(alice), 2000e6);
        assertEq(cm.totalExposure(), 2000e6);
    }

    // ─── Health Factor
    // ───────────────────────────────────────────

    function test_HealthFactor_ZeroExposure_ReturnsMaxUint() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        assertEq(cm.healthFactor(alice), type(uint256).max);
    }

    function test_HealthFactor_CorrectCalculation() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 5000e6);

        // hf = (10000 * 10000) / 5000 = 20000 (200%)
        assertEq(cm.healthFactor(alice), 20_000);
    }

    // ─── Liquidation
    // ─────────────────────────────────────────────

    function test_Liquidate_FullScenario() public {
        // Setup: alice deposits collateral and gets exposed to max LTV
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 7500e6);

        // hf = 10000*10000/7500 = 13333 > 8500, not liquidatable
        assertFalse(cm.isLiquidatable(alice));

        // Simulate external loss: directly reduce alice's collateral via vm.store
        // to create a liquidatable position (as if oracle-triggered collateral loss)
        // collateralBalances mapping is at slot 2, totalCollateral is at slot 4
        bytes32 aliceCollateralSlot = keccak256(abi.encode(alice, uint256(2)));
        vm.store(address(cm), aliceCollateralSlot, bytes32(uint256(6000e6)));
        vm.store(address(cm), bytes32(uint256(4)), bytes32(uint256(6000e6)));

        // hf = 6000*10000/7500 = 8000 < 8500 → liquidatable
        assertTrue(cm.isLiquidatable(alice));

        // Liquidate
        uint256 liquidatorBalBefore = usdc.balanceOf(liquidator);
        cm.liquidate(alice, liquidator);

        // Seized = min(7500 * 500 / 10000, 6000) = min(375e6, 6000e6) = 375e6
        uint256 expectedSeized = (7500e6 * 500) / 10_000;
        assertEq(usdc.balanceOf(liquidator) - liquidatorBalBefore, expectedSeized);
        assertEq(cm.coverageExposure(alice), 0);
        assertEq(cm.collateralBalances(alice), 6000e6 - expectedSeized);
    }

    function test_Liquidate_NotLiquidatable_Reverts() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 1000e6);

        // hf = 10000*10000/1000 = 100000 >> 8500
        vm.expectRevert(CollateralManager.NotLiquidatable.selector);
        cm.liquidate(alice, liquidator);
    }

    // ─── Utilization Rate
    // ────────────────────────────────────────

    function test_UtilizationRate_ZeroCollateral_ReturnsZero() public view {
        assertEq(cm.utilizationRate(), 0);
    }

    function test_UtilizationRate_Calculation() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 5000e6);

        // 5000 * 1e18 / 10000 = 5e17 (50%)
        assertEq(cm.utilizationRate(), 5e17);
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_HealthFactor(uint256 collateral, uint256 exposure) public {
        collateral = bound(collateral, 1e6, 500_000e6);

        usdc.mint(alice, collateral);
        vm.prank(alice);
        usdc.approve(address(cm), collateral);

        vm.prank(alice);
        cm.depositCollateral(collateral);

        uint256 maxExposure = (collateral * 7500) / 10_000;
        exposure = bound(exposure, 1, maxExposure);

        vm.prank(pool);
        cm.increaseExposure(alice, exposure);

        // If increaseExposure didn't revert, hf should be >= LIQUIDATION_THRESHOLD
        assertGe(cm.healthFactor(alice), cm.LIQUIDATION_THRESHOLD());
    }
}
