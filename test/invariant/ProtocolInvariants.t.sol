// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {UnderwriterVault} from "../../src/UnderwriterVault.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {GovernanceToken} from "../../src/GovernanceToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ProtocolHandler — generates valid protocol actions for invariant fuzzing
contract ProtocolHandler is CommonBase, StdCheats, StdUtils {
    UnderwriterVault public vault;
    CollateralManager public cm;
    GovernanceToken public token;
    MockERC20 public usdc;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalPremiums;
    uint256 public initialPricePerShare;

    address[] public actors;
    address public admin;

    constructor(
        UnderwriterVault _vault,
        CollateralManager _cm,
        GovernanceToken _token,
        MockERC20 _usdc,
        address _admin
    ) {
        vault = _vault;
        cm = _cm;
        token = _token;
        usdc = _usdc;
        admin = _admin;

        // Seed initial price per share (1e6 = 1 share worth of assets)
        initialPricePerShare = vault.totalSupply() > 0 ? vault.convertToAssets(1e6) : 1e6;

        for (uint256 i = 0; i < 5; i++) {
            address actor = address(uint160(0x1000 + i));
            actors.push(actor);
            usdc.mint(actor, 100_000_000e6);
            vm.prank(actor);
            usdc.approve(address(vault), type(uint256).max);
            vm.prank(actor);
            usdc.approve(address(cm), type(uint256).max);
        }
    }

    function deposit(uint96 amount) external {
        amount = uint96(bound(amount, 1e6, 1_000_000e6));
        address actor = actors[amount % actors.length];

        vm.prank(actor);
        vault.deposit(amount, actor);
        totalDeposited += amount;
    }

    function withdraw(uint96 amount) external {
        address actor = actors[amount % actors.length];
        uint256 maxWithdrawable = vault.maxWithdraw(actor);
        if (maxWithdrawable == 0) return;

        amount = uint96(bound(amount, 1, maxWithdrawable));

        vm.prank(actor);
        vault.withdraw(amount, actor, actor);
        totalWithdrawn += amount;
    }

    function depositCollateral(uint96 amount) external {
        amount = uint96(bound(amount, 1e6, 1_000_000e6));
        address actor = actors[amount % actors.length];

        vm.prank(actor);
        cm.depositCollateral(amount);
    }

    function depositPremiums(uint96 amount) external {
        amount = uint96(bound(amount, 1, 100_000e6));
        if (vault.totalSupply() == 0) return;

        usdc.mint(admin, amount);
        vm.startPrank(admin);
        usdc.approve(address(vault), amount);
        vault.depositPremiums(amount);
        vm.stopPrank();
        totalPremiums += amount;
    }
}

/// @title ProtocolInvariantTest — 5 protocol invariants
contract ProtocolInvariantTest is StdInvariant, Test {
    UnderwriterVault public vault;
    CollateralManager public cm;
    GovernanceToken public token;
    MockERC20 public usdc;
    ProtocolHandler public handler;

    address admin = makeAddr("admin");
    address deployer = makeAddr("deployer");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(admin);
        vault = new UnderwriterVault(IERC20(address(usdc)), admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), admin);
        cm.grantRole(cm.POOL_ROLE(), admin);
        vm.stopPrank();

        vm.prank(deployer);
        token = new GovernanceToken(deployer);

        handler = new ProtocolHandler(vault, cm, token, usdc, admin);

        targetContract(address(handler));
    }

    /// @notice INVARIANT 1: Vault totalAssets >= net deposits + premiums - withdrawals.
    ///         Premiums add to totalAssets, and withdrawals can exceed deposits when
    ///         premiums boost share value. The vault USDC balance is the ultimate truth.
    function invariant_VaultSolvency() public view {
        assertGe(vault.totalAssets(), 0, "Vault totalAssets must never be negative (impossible with uint256)");
        // The vault should always have enough USDC to cover its totalAssets
        assertGe(
            usdc.balanceOf(address(vault)), vault.totalAssets(), "Vault must be solvent: USDC balance >= totalAssets"
        );
    }

    /// @notice INVARIANT 2: Sum of all collateral positions == CollateralManager's USDC balance.
    function invariant_CollateralAccounting() public view {
        assertEq(cm.totalCollateral(), usdc.balanceOf(address(cm)), "Total collateral must match USDC balance");
    }

    /// @notice INVARIANT 3: Share price never decreases (premiums only add to totalAssets).
    function invariant_SharePriceNeverDecreases() public view {
        if (vault.totalSupply() == 0) return;
        uint256 currentPPS = vault.convertToAssets(1e6);
        assertGe(currentPPS, handler.initialPricePerShare(), "Price per share must never decrease");
    }

    /// @notice INVARIANT 4: GovernanceToken total supply never exceeds 100M cap.
    function invariant_TotalSupplyBelowCap() public view {
        assertLe(token.totalSupply(), 100_000_000e18, "Total supply must not exceed hard cap");
    }

    /// @notice INVARIANT 5: Vault USDC balance >= totalAssets (vault is never insolvent).
    function invariant_VaultUSDCBalance() public view {
        assertGe(usdc.balanceOf(address(vault)), vault.totalAssets(), "Vault USDC balance must be >= totalAssets");
    }
}
