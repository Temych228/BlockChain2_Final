// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InsurancePool} from "../../src/InsurancePool.sol";
import {InsurancePoolV2} from "../../src/InsurancePoolV2.sol";
import {UnderwriterVault} from "../../src/UnderwriterVault.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {PolicyNFT} from "../../src/PolicyNFT.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract MockOracle2 {
    function getPrice() external view returns (uint256, uint256) {
        return (2000e8, block.timestamp);
    }
}

/// @title InsurancePool Integration Tests — Extended
/// @notice Covers missing edge cases: insufficient allowance, already-claimed, expired policy.
contract InsurancePoolIntegrationTest is Test {
    InsurancePool public pool;
    UnderwriterVault public vault;
    CollateralManager public cm;
    PolicyNFT public nft;
    MockERC20 public usdc;
    MockOracle2 public oracle;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        oracle = new MockOracle2();

        vm.startPrank(admin);

        vault = new UnderwriterVault(IERC20(address(usdc)), admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        nft = new PolicyNFT("https://api.insuredao.io/policy/", admin);

        InsurancePool impl = new InsurancePool();
        bytes memory initData = abi.encodeWithSelector(
            InsurancePool.initialize.selector,
            address(vault), address(cm), address(nft), address(oracle), address(usdc), admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        pool = InsurancePool(address(proxy));

        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), address(pool));
        cm.grantRole(cm.POOL_ROLE(), address(pool));
        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        nft.grantRole(nft.BURNER_ROLE(), address(pool));
        pool.addPolicyType(0, 100_000e6, 1e18);

        vm.stopPrank();

        usdc.mint(alice, 10_000_000e6);
        usdc.mint(bob, 10_000_000e6);

        // Collective pool backing
        usdc.mint(address(pool), 2_000_000e6);
        vm.startPrank(address(pool));
        usdc.approve(address(cm), type(uint256).max);
        cm.depositCollateral(1_000_000e6);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000e6, address(pool));
        vm.stopPrank();

        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);
    }

    function test_PurchasePolicy_InsufficientAllowance_Reverts() public {
        // First create utilization so premiums are non-zero
        vm.prank(alice);
        pool.purchasePolicy(0, 50_000e6, 30 days);

        // Reset bob's approval to 0
        vm.prank(bob);
        usdc.approve(address(pool), 0);

        // Now bob tries to buy — premium > 0 so safeTransferFrom will fail
        vm.prank(bob);
        vm.expectRevert();
        pool.purchasePolicy(0, 10_000e6, 30 days);
    }

    function test_ProcessClaim_AlreadyClaimed_Reverts() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(0, 10_000e6, 30 days);

        vm.prank(admin);
        pool.triggerPolicy(policyId);

        vm.prank(admin);
        pool.processClaim(policyId);

        // Try to claim again
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsurancePool.InvalidPolicyState.selector,
                InsurancePool.PolicyState.CLAIMED,
                InsurancePool.PolicyState.TRIGGERED
            )
        );
        pool.processClaim(policyId);
    }

    function test_TriggerPolicy_ExpiredPolicy_Reverts() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(0, 5_000e6, 1 days);

        // Warp past expiry
        vm.warp(block.timestamp + 2 days);

        vm.prank(admin);
        vm.expectRevert(InsurancePool.PolicyExpired.selector);
        pool.triggerPolicy(policyId);
    }

    function test_ProcessClaim_HolderReceivesExactPayout() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(0, 20_000e6, 30 days);

        uint256 aliceBalBefore = usdc.balanceOf(alice);

        vm.prank(admin);
        pool.triggerPolicy(policyId);
        vm.prank(admin);
        pool.processClaim(policyId);

        assertEq(usdc.balanceOf(alice) - aliceBalBefore, 20_000e6);
    }

    function test_MultipleUsers_PurchasePolicies() public {
        vm.prank(alice);
        uint256 p1 = pool.purchasePolicy(0, 5_000e6, 30 days);

        vm.prank(bob);
        uint256 p2 = pool.purchasePolicy(0, 8_000e6, 60 days);

        assertEq(p1, 0);
        assertEq(p2, 1);
        assertEq(pool.nextPolicyId(), 2);

        (address h1,,,,, ) = pool.policies(p1);
        (address h2,,,,, ) = pool.policies(p2);
        assertEq(h1, alice);
        assertEq(h2, bob);
    }

    function test_Pause_Unpause_ResumesOperations() public {
        vm.prank(admin);
        pool.pause();

        vm.prank(alice);
        vm.expectRevert();
        pool.purchasePolicy(0, 1000e6, 30 days);

        vm.prank(admin);
        pool.unpause();

        vm.prank(alice);
        pool.purchasePolicy(0, 1000e6, 30 days);
    }

    function test_GetVersion_V1() public view {
        assertEq(pool.getVersion(), "V1");
    }

    function test_UpgradeToV2_PurchaseIncrementsPolicyCount() public {
        vm.prank(alice);
        pool.purchasePolicy(0, 5000e6, 30 days);

        vm.startPrank(admin);
        InsurancePoolV2 v2Impl = new InsurancePoolV2();
        pool.upgradeToAndCall(address(v2Impl), "");
        InsurancePoolV2 poolV2 = InsurancePoolV2(address(pool));
        poolV2.initializeV2();
        vm.stopPrank();

        assertEq(poolV2.policyCount(), 1);

        vm.prank(bob);
        poolV2.purchasePolicy(0, 3000e6, 30 days);

        assertEq(poolV2.policyCount(), 2);
        assertEq(poolV2.getVersion(), "V2");
    }
}
