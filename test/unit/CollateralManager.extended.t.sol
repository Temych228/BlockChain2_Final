// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title CollateralManager Extended Unit Tests
/// @notice Covers missing edge cases: liquidation bonus, exposure reset, role enforcement.
contract CollateralManagerExtendedTest is Test {
    CollateralManager public cm;
    MockERC20 public usdc;

    address admin = makeAddr("admin");
    address pool = makeAddr("pool");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address liquidator = makeAddr("liquidator");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        cm.grantRole(cm.POOL_ROLE(), pool);
        vm.stopPrank();

        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);

        vm.prank(alice);
        usdc.approve(address(cm), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(cm), type(uint256).max);
    }

    function test_Liquidate_SendsBonusToLiquidator() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 7500e6);

        // Force HF below threshold via vm.store
        bytes32 collSlot = keccak256(abi.encode(alice, uint256(2)));
        vm.store(address(cm), collSlot, bytes32(uint256(6000e6)));
        vm.store(address(cm), bytes32(uint256(4)), bytes32(uint256(6000e6)));

        uint256 liqBalBefore = usdc.balanceOf(liquidator);
        cm.liquidate(alice, liquidator);

        // Seized = exposure * LIQUIDATION_BONUS / BASIS_POINTS = 7500 * 500 / 10000 = 375 USDC
        uint256 expectedBonus = (7500e6 * 500) / 10_000;
        assertEq(usdc.balanceOf(liquidator) - liqBalBefore, expectedBonus);
    }

    function test_Liquidate_ResetsExposure() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        cm.increaseExposure(alice, 7500e6);

        bytes32 collSlot = keccak256(abi.encode(alice, uint256(2)));
        vm.store(address(cm), collSlot, bytes32(uint256(5000e6)));
        vm.store(address(cm), bytes32(uint256(4)), bytes32(uint256(5000e6)));

        assertTrue(cm.isLiquidatable(alice));

        cm.liquidate(alice, liquidator);

        assertEq(cm.coverageExposure(alice), 0, "Exposure should be reset to 0 after liquidation");
        assertEq(cm.healthFactor(alice), type(uint256).max, "Health factor should be max with 0 exposure");
    }

    function test_DecreaseExposure_OnlyPoolRole() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);
        vm.prank(pool);
        cm.increaseExposure(alice, 1000e6);

        bytes32 role = cm.POOL_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        cm.decreaseExposure(alice, 500e6);
    }

    function test_DepositCollateral_MultipleUsers() public {
        vm.prank(alice);
        cm.depositCollateral(5000e6);
        vm.prank(bob);
        cm.depositCollateral(3000e6);

        assertEq(cm.totalCollateral(), 8000e6);
        assertEq(cm.collateralBalances(alice), 5000e6);
        assertEq(cm.collateralBalances(bob), 3000e6);
    }

    function test_WithdrawCollateral_ZeroReverts() public {
        vm.prank(alice);
        cm.depositCollateral(1000e6);

        vm.prank(alice);
        vm.expectRevert(CollateralManager.ZeroAmount.selector);
        cm.withdrawCollateral(0);
    }

    function test_Pause_BlocksDeposit() public {
        vm.prank(admin);
        cm.pause();

        vm.prank(alice);
        vm.expectRevert();
        cm.depositCollateral(1000e6);
    }

    function test_Pause_BlocksWithdraw() public {
        vm.prank(alice);
        cm.depositCollateral(1000e6);

        vm.prank(admin);
        cm.pause();

        vm.prank(alice);
        vm.expectRevert();
        cm.withdrawCollateral(500e6);
    }

    function test_Unpause_ResumesOperations() public {
        vm.prank(admin);
        cm.pause();
        vm.prank(admin);
        cm.unpause();

        vm.prank(alice);
        cm.depositCollateral(1000e6);
        assertEq(cm.collateralBalances(alice), 1000e6);
    }

    function test_IncreaseExposure_ZeroReverts() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);

        vm.prank(pool);
        vm.expectRevert(CollateralManager.ZeroAmount.selector);
        cm.increaseExposure(alice, 0);
    }

    function test_DecreaseExposure_ZeroReverts() public {
        vm.prank(alice);
        cm.depositCollateral(10_000e6);
        vm.prank(pool);
        cm.increaseExposure(alice, 1000e6);

        vm.prank(pool);
        vm.expectRevert(CollateralManager.ZeroAmount.selector);
        cm.decreaseExposure(alice, 0);
    }
}
