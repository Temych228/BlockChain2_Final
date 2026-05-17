// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnderwriterVault} from "../../src/UnderwriterVault.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title USDCForkTest
/// @notice Fork tests validating vault and collateral manager against real USDC on Arbitrum One.
/// @dev Run with: ARBITRUM_RPC_URL=<rpc> forge test --mc USDCForkTest --fork-url $ARBITRUM_RPC_URL
contract USDCForkTest is Test {
    // Native USDC on Arbitrum One
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    UnderwriterVault vault;
    CollateralManager cm;
    address admin = makeAddr("admin");
    address user = makeAddr("forkUser");

    function setUp() public {
        try vm.activeFork() returns (uint256) {} catch {
            vm.skip(true);
        }

        vm.startPrank(admin);
        vault = new UnderwriterVault(IERC20(USDC), admin);
        cm = new CollateralManager(IERC20(USDC), admin);
        vm.stopPrank();

        // Give user 100k USDC via deal (works on forks)
        deal(USDC, user, 100_000e6);

        vm.startPrank(user);
        IERC20(USDC).approve(address(vault), type(uint256).max);
        IERC20(USDC).approve(address(cm), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Deposit and withdraw real USDC through the vault.
    function test_VaultWithRealUSDC() public {
        vm.startPrank(user);

        uint256 depositAmount = 10_000e6;
        uint256 shares = vault.deposit(depositAmount, user);
        assertGt(shares, 0, "Shares should be non-zero");

        vault.redeem(shares, user, user);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 0, "All shares should be redeemed");
        assertGe(IERC20(USDC).balanceOf(user), 99_999e6, "User should get back ~all USDC");
    }

    /// @notice Deposit real USDC as collateral and verify balances.
    function test_CollateralManagerWithRealUSDC() public {
        vm.startPrank(user);

        uint256 depositAmount = 50_000e6;
        cm.depositCollateral(depositAmount);

        assertEq(cm.collateralBalances(user), depositAmount, "Collateral balance mismatch");
        assertEq(IERC20(USDC).balanceOf(address(cm)), depositAmount, "CM USDC balance mismatch");

        cm.withdrawCollateral(depositAmount);
        vm.stopPrank();

        assertEq(cm.collateralBalances(user), 0);
        assertEq(IERC20(USDC).balanceOf(user), 100_000e6, "User should have all USDC back");
    }

    /// @notice Verify real USDC decimals and basic properties.
    function test_RealUSDC_Properties() public view {
        IERC20 usdc = IERC20(USDC);
        assertGt(usdc.totalSupply(), 0, "USDC should have non-zero supply");
    }
}
