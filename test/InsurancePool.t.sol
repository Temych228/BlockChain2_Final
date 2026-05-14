// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {InsurancePoolV2} from "../src/InsurancePoolV2.sol";
import {UnderwriterVault} from "../src/UnderwriterVault.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {PolicyNFT} from "../src/PolicyNFT.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @dev Minimal mock oracle for tests.
contract MockOracle {
    function getPrice() external view returns (uint256, uint256) {
        return (2000e8, block.timestamp);
    }
}

contract InsurancePoolTest is Test {
    InsurancePool public pool;
    InsurancePool public poolImpl;
    UnderwriterVault public vault;
    CollateralManager public cm;
    PolicyNFT public nft;
    MockERC20 public usdc;
    MockOracle public oracle;

    address public admin;
    address public alice;
    address public bob;

    uint256 constant POLICY_TYPE_DEPEG = 0;

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy infrastructure
        usdc = new MockERC20("USD Coin", "USDC", 6);
        oracle = new MockOracle();

        vm.startPrank(admin);

        vault = new UnderwriterVault(IERC20(address(usdc)), admin);
        cm = new CollateralManager(IERC20(address(usdc)), admin);
        nft = new PolicyNFT("https://api.insuredao.io/policy/", admin);

        // Deploy InsurancePool via proxy
        poolImpl = new InsurancePool();
        bytes memory initData = abi.encodeWithSelector(
            InsurancePool.initialize.selector,
            address(vault),
            address(cm),
            address(nft),
            address(oracle),
            address(usdc),
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(poolImpl), initData);
        pool = InsurancePool(address(proxy));

        // Configure roles
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), address(pool));
        cm.grantRole(cm.POOL_ROLE(), address(pool));
        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        nft.grantRole(nft.BURNER_ROLE(), address(pool));

        // Add a policy type
        pool.addPolicyType(POLICY_TYPE_DEPEG, 100_000e6, 1e18);

        vm.stopPrank();

        // Fund users
        usdc.mint(alice, 10_000_000e6);
        usdc.mint(bob, 10_000_000e6);
        usdc.mint(admin, 10_000_000e6);

        // Deposit collateral on behalf of the pool proxy (collective underwriter backing)
        usdc.mint(address(pool), 2_000_000e6);
        vm.startPrank(address(pool));
        usdc.approve(address(cm), type(uint256).max);
        cm.depositCollateral(1_000_000e6);
        // Also deposit into vault so there are assets to withdraw on claims
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000e6, address(pool));
        vm.stopPrank();

        // Approve USDC for pool
        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);
    }

    // ─── Purchase Policy
    // ─────────────────────────────────────────

    function test_PurchasePolicy_Success() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        assertEq(policyId, 0);
        assertEq(pool.nextPolicyId(), 1);

        (address holder, uint256 typeId, uint256 coverage,, uint256 expiry, InsurancePool.PolicyState state) =
            pool.policies(policyId);
        assertEq(holder, alice);
        assertEq(typeId, POLICY_TYPE_DEPEG);
        assertEq(coverage, 10_000e6);
        assertEq(uint8(state), uint8(InsurancePool.PolicyState.ACTIVE));
        assertGt(expiry, block.timestamp);

        // Alice should have received a policy NFT
        assertEq(nft.balanceOf(alice, POLICY_TYPE_DEPEG), 1);
    }

    function test_PurchasePolicy_InactiveType_Reverts() public {
        // Use non-existent type
        vm.prank(alice);
        vm.expectRevert(InsurancePool.PolicyTypeInactive.selector);
        pool.purchasePolicy(99, 1000e6, 30 days);
    }

    function test_PurchasePolicy_ExceedsMaxCoverage_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InsurancePool.CoverageExceedsMax.selector, 200_000e6, 100_000e6));
        pool.purchasePolicy(POLICY_TYPE_DEPEG, 200_000e6, 30 days);
    }

    function test_PurchasePolicy_DurationTooLong_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InsurancePool.DurationTooLong.selector, 366 days, 365 days));
        pool.purchasePolicy(POLICY_TYPE_DEPEG, 1000e6, 366 days);
    }

    // ─── Trigger & Claim
    // ─────────────────────────────────────────

    function test_TriggerPolicy_Success() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        vm.prank(admin);
        pool.triggerPolicy(policyId);

        (,,,,, InsurancePool.PolicyState state) = pool.policies(policyId);
        assertEq(uint8(state), uint8(InsurancePool.PolicyState.TRIGGERED));
    }

    function test_TriggerPolicy_WrongRole_Reverts() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        bytes32 role = pool.CLAIM_PROCESSOR_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        pool.triggerPolicy(policyId);
    }

    function test_TriggerPolicy_AlreadyTriggered_Reverts() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        vm.prank(admin);
        pool.triggerPolicy(policyId);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsurancePool.InvalidPolicyState.selector,
                InsurancePool.PolicyState.TRIGGERED,
                InsurancePool.PolicyState.ACTIVE
            )
        );
        pool.triggerPolicy(policyId);
    }

    function test_ProcessClaim_FullFlow() public {
        // Purchase
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        // Trigger
        vm.prank(admin);
        pool.triggerPolicy(policyId);

        // Process claim — approve vault to spend from pool
        uint256 aliceBalBefore = usdc.balanceOf(alice);
        vm.prank(admin);
        pool.processClaim(policyId);

        // Alice should have received the coverage payout
        assertEq(usdc.balanceOf(alice) - aliceBalBefore, 10_000e6);

        (,,,,, InsurancePool.PolicyState state) = pool.policies(policyId);
        assertEq(uint8(state), uint8(InsurancePool.PolicyState.CLAIMED));

        // NFT should be burned
        assertEq(nft.balanceOf(alice, POLICY_TYPE_DEPEG), 0);
    }

    function test_ProcessClaim_NotTriggered_Reverts() public {
        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, 10_000e6, 30 days);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsurancePool.InvalidPolicyState.selector,
                InsurancePool.PolicyState.ACTIVE,
                InsurancePool.PolicyState.TRIGGERED
            )
        );
        pool.processClaim(policyId);
    }

    // ─── Pause
    // ───────────────────────────────────────────────────

    function test_Pause_BlocksPurchase() public {
        vm.prank(admin);
        pool.pause();

        vm.prank(alice);
        vm.expectRevert();
        pool.purchasePolicy(POLICY_TYPE_DEPEG, 1000e6, 30 days);
    }

    // ─── Policy Type Management
    // ──────────────────────────────────

    function test_AddPolicyType_Success() public {
        vm.prank(admin);
        pool.addPolicyType(5, 50_000e6, 2e18);

        (uint256 maxCov, uint256 riskMul, bool active) = pool.policyTypes(5);
        assertEq(maxCov, 50_000e6);
        assertEq(riskMul, 2e18);
        assertTrue(active);
    }

    function test_AddPolicyType_WrongRole_Reverts() public {
        bytes32 role = pool.POLICY_MANAGER_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        pool.addPolicyType(5, 50_000e6, 2e18);
    }

    // ─── Version
    // ─────────────────────────────────────────────────

    function test_GetVersion_V1() public view {
        assertEq(pool.getVersion(), "V1");
    }

    // ─── UUPS Upgrade
    // ────────────────────────────────────────────

    function test_UpgradeToV2() public {
        // Purchase a policy before upgrade
        vm.prank(alice);
        pool.purchasePolicy(POLICY_TYPE_DEPEG, 5000e6, 30 days);
        assertEq(pool.nextPolicyId(), 1);

        // Deploy V2 and upgrade
        vm.startPrank(admin);
        InsurancePoolV2 v2Impl = new InsurancePoolV2();
        pool.upgradeToAndCall(address(v2Impl), "");

        // Now pool is V2
        InsurancePoolV2 poolV2 = InsurancePoolV2(address(pool));
        poolV2.initializeV2();
        vm.stopPrank();

        // Verify V2 features
        assertEq(poolV2.getVersion(), "V2");
        assertEq(poolV2.policyCount(), 1); // migrated from nextPolicyId

        // Verify V1 storage intact
        (address holder,,,,, InsurancePool.PolicyState state) = poolV2.policies(0);
        assertEq(holder, alice);
        assertEq(uint8(state), uint8(InsurancePool.PolicyState.ACTIVE));
        assertEq(poolV2.nextPolicyId(), 1);
    }

    function test_UpgradeToV2_Unauthorized_Reverts() public {
        InsurancePoolV2 v2Impl = new InsurancePoolV2();

        bytes32 role = pool.DEFAULT_ADMIN_ROLE();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        pool.upgradeToAndCall(address(v2Impl), "");
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_PurchasePolicy(uint256 coverage, uint256 duration) public {
        coverage = bound(coverage, 1e6, 100_000e6);
        duration = bound(duration, 1 days, 365 days);

        vm.prank(alice);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE_DEPEG, coverage, duration);

        (address holder, uint256 typeId, uint256 cov,,, InsurancePool.PolicyState state) = pool.policies(policyId);
        assertEq(holder, alice);
        assertEq(typeId, POLICY_TYPE_DEPEG);
        assertEq(cov, coverage);
        assertEq(uint8(state), uint8(InsurancePool.PolicyState.ACTIVE));
    }
}
