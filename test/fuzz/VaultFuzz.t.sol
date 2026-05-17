// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnderwriterVault} from "../../src/UnderwriterVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title VaultFuzz — Fuzz tests for UnderwriterVault
/// @notice testFuzz_NoFreeMoney, testFuzz_SharesMonotonicallyIncrease, testFuzz_PremiumsIncreasePricePerShare
contract VaultFuzzTest is Test {
    UnderwriterVault public vault;
    MockERC20 public usdc;

    address admin = makeAddr("admin");
    address depositor = makeAddr("depositor");
    address alice = makeAddr("alice");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        vault = new UnderwriterVault(IERC20(address(usdc)), admin);
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), depositor);
        vm.stopPrank();

        usdc.mint(alice, 100_000_000e6);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);

        usdc.mint(depositor, 100_000_000e6);
        vm.prank(depositor);
        usdc.approve(address(vault), type(uint256).max);
    }

    /// @notice Deposit X, withdraw immediately — user gets back ≤ X (no free money).
    function testFuzz_NoFreeMoney(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 1_000_000e6));

        uint256 balBefore = usdc.balanceOf(alice);

        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertLe(usdc.balanceOf(alice), balBefore, "User must not profit from deposit+withdraw");
    }

    /// @notice More deposits = more shares. Shares increase monotonically.
    function testFuzz_SharesMonotonicallyIncrease(uint96 first, uint96 second) public {
        first = uint96(bound(first, 1e6, 10_000_000e6));
        second = uint96(bound(second, 1e6, 10_000_000e6));

        vm.startPrank(alice);
        uint256 shares1 = vault.deposit(first, alice);
        uint256 shares2 = vault.deposit(second, alice);
        vm.stopPrank();

        assertGt(shares1 + shares2, shares1, "Total shares should increase with additional deposits");
        assertGt(shares2, 0, "Second deposit should yield non-zero shares");
    }

    /// @notice After depositPremiums, pricePerShare goes up for existing depositors.
    function testFuzz_PremiumsIncreasePricePerShare(uint96 collateral, uint96 premium) public {
        collateral = uint96(bound(collateral, 1e6, 10_000_000e6));
        premium = uint96(bound(premium, 1, collateral));

        vm.prank(alice);
        vault.deposit(collateral, alice);

        uint256 ppsBefore = vault.convertToAssets(1e6);

        vm.prank(depositor);
        vault.depositPremiums(premium);

        uint256 ppsAfter = vault.convertToAssets(1e6);
        assertGe(ppsAfter, ppsBefore, "Price per share must not decrease after premiums");
    }
}
