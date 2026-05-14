// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UnderwriterVault} from "../src/UnderwriterVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract UnderwriterVaultTest is Test {
    UnderwriterVault public vault;
    MockERC20 public usdc;

    address public admin;
    address public premiumDepositor;
    address public alice;
    address public bob;

    function setUp() public {
        admin = makeAddr("admin");
        premiumDepositor = makeAddr("premiumDepositor");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        vault = new UnderwriterVault(IERC20(address(usdc)), admin);
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), premiumDepositor);
        vm.stopPrank();

        // Fund test accounts
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);
        usdc.mint(premiumDepositor, 1_000_000e6);

        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(premiumDepositor);
        usdc.approve(address(vault), type(uint256).max);
    }

    // ─── Deposit
    // ─────────────────────────────────────────────────

    function test_Deposit_SharesCorrect() public {
        // First deposit: 1:1 ratio
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);

        assertEq(shares, 10_000e6);
        assertEq(vault.balanceOf(alice), 10_000e6);
        assertEq(vault.totalAssets(), 10_000e6);
    }

    function test_Deposit_SecondDepositor_SharesProportional() public {
        // Alice deposits first
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // Bob deposits same amount — should get same shares
        vm.prank(bob);
        uint256 bobShares = vault.deposit(10_000e6, bob);

        assertEq(bobShares, 10_000e6);
        assertEq(vault.totalAssets(), 20_000e6);
    }

    // ─── Withdraw
    // ────────────────────────────────────────────────

    function test_Withdraw_FullAmount() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        uint256 balBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(10_000e6, alice, alice);

        assertEq(usdc.balanceOf(alice) - balBefore, 10_000e6);
        assertEq(vault.balanceOf(alice), 0);
    }

    function test_Withdraw_MoreThanBalance_Reverts() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(20_000e6, alice, alice);
    }

    // ─── Deposit Premiums
    // ────────────────────────────────────────

    function test_DepositPremiums_IncreasesTotalAssets() public {
        // Alice deposits collateral
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        uint256 totalBefore = vault.totalAssets();

        // Premium depositor adds premiums
        vm.prank(premiumDepositor);
        vault.depositPremiums(500e6);

        assertEq(vault.totalAssets(), totalBefore + 500e6);
    }

    function test_DepositPremiums_OnlyRole() public {
        bytes32 role = vault.PREMIUM_DEPOSITOR_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        vault.depositPremiums(100e6);
    }

    function test_DepositPremiums_ZeroAmount_Reverts() public {
        vm.prank(premiumDepositor);
        vm.expectRevert(UnderwriterVault.ZeroAmount.selector);
        vault.depositPremiums(0);
    }

    function test_DepositAfterPremiums_CorrectShares() public {
        // Alice deposits first
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // Premiums deposited
        vm.prank(premiumDepositor);
        vault.depositPremiums(1000e6);

        // Now totalAssets = 11_000e6, totalShares = 10_000e6
        // Bob deposits 11_000e6 -> should get 10_000e6 shares
        vm.prank(bob);
        uint256 bobShares = vault.deposit(11_000e6, bob);

        assertEq(bobShares, 10_000e6);
    }

    // ─── Pause
    // ───────────────────────────────────────────────────

    function test_Pause_BlocksDeposit() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1000e6, alice);
    }

    function test_Pause_BlocksWithdraw() public {
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        vm.prank(admin);
        vault.pause();

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(1000e6, alice, alice);
    }

    function test_Unpause_AllowsDeposit() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(admin);
        vault.unpause();

        vm.prank(alice);
        vault.deposit(1000e6, alice);
        assertEq(vault.balanceOf(alice), 1000e6);
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_DepositWithdraw(uint256 amount) public {
        // No free money invariant
        amount = bound(amount, 1e6, 500_000e6);

        uint256 balBefore = usdc.balanceOf(alice);

        vm.startPrank(alice);
        uint256 shares = vault.deposit(amount, alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        uint256 balAfter = usdc.balanceOf(alice);
        // User should get back ≤ deposited amount (rounding may cause 1 wei loss)
        assertLe(balBefore - balAfter, 1, "Should lose at most 1 wei to rounding");
    }

    function testFuzz_RoundingInvariant(uint256 assets) public view {
        // ERC-4626 invariant: converting assets→shares→assets should not create money
        assets = bound(assets, 1, 1_000_000e6);

        uint256 shares = vault.previewDeposit(assets);
        uint256 assetsBack = vault.previewRedeem(shares);

        assertLe(assetsBack, assets, "Redeeming deposited shares must not return more than deposited");
    }
}
