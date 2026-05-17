// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/GovernanceToken.sol";
import {UnderwriterVault} from "../../src/UnderwriterVault.sol";
import {CollateralManager} from "../../src/CollateralManager.sol";
import {InsurancePool} from "../../src/InsurancePool.sol";
import {PolicyNFT} from "../../src/PolicyNFT.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @dev Minimal mock oracle for gas tests.
contract GasMockOracle {
    function getPrice() external view returns (uint256, uint256) {
        return (2000e8, block.timestamp);
    }
}

/// @title GasSnapshot
/// @notice Measures gas for 6 key protocol operations (rubric §3.1 gas comparison L1 vs L2).
///         Run with `forge test --match-contract GasSnapshot -vv` to see gas logs.
contract GasSnapshot is Test {
    GovernanceToken token;
    MockERC20 usdc;
    UnderwriterVault vault;
    CollateralManager cm;
    InsurancePool pool;
    PolicyNFT nft;
    GasMockOracle oracle;

    address deployer = makeAddr("deployer");
    address underwriter = makeAddr("underwriter");
    address policyHolder = makeAddr("policyHolder");
    address liquidator = makeAddr("liquidator");
    address delegator = makeAddr("delegator");

    uint256 constant POLICY_TYPE = 0;

    function setUp() public {
        vm.warp(100_000);

        vm.startPrank(deployer);

        token = new GovernanceToken(deployer);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        oracle = new GasMockOracle();
        nft = new PolicyNFT("https://api.insuredao.io/policy/", deployer);
        vault = new UnderwriterVault(IERC20(address(usdc)), deployer);
        cm = new CollateralManager(IERC20(address(usdc)), deployer);

        InsurancePool impl = new InsurancePool();
        bytes memory initData = abi.encodeWithSelector(
            InsurancePool.initialize.selector,
            address(vault),
            address(cm),
            address(nft),
            address(oracle),
            address(usdc),
            deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        pool = InsurancePool(address(proxy));

        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), address(pool));
        cm.grantRole(cm.POOL_ROLE(), address(pool));
        nft.grantRole(nft.MINTER_ROLE(), address(pool));
        nft.grantRole(nft.BURNER_ROLE(), address(pool));

        pool.addPolicyType(POLICY_TYPE, 100_000e6, 1e18);

        vm.stopPrank();

        // Fund pool with collateral (collective backing)
        usdc.mint(address(pool), 2_000_000e6);
        vm.startPrank(address(pool));
        usdc.approve(address(cm), type(uint256).max);
        cm.depositCollateral(1_000_000e6);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(1_000_000e6, address(pool));
        vm.stopPrank();

        // Fund underwriter for vault operations
        usdc.mint(underwriter, 500_000e6);
        vm.prank(underwriter);
        usdc.approve(address(vault), type(uint256).max);

        // Fund policy holder
        usdc.mint(policyHolder, 500_000e6);
        vm.prank(policyHolder);
        usdc.approve(address(pool), type(uint256).max);

        // Fund underwriter for collateral operations
        vm.prank(underwriter);
        usdc.approve(address(cm), type(uint256).max);

        // Fund delegator with governance tokens
        vm.prank(deployer);
        token.transfer(delegator, 100_000e18);
    }

    // ═══════════════════════════════════════════════════════════════
    // 6 Gas-Measured Operations
    // ═══════════════════════════════════════════════════════════════

    /// @notice Operation 1: GovernanceToken.delegate()
    function test_Gas_Delegate() public {
        vm.prank(delegator);
        uint256 gasBefore = gasleft();
        token.delegate(delegator);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("1. delegate() gas:", gasUsed);
    }

    /// @notice Operation 2: UnderwriterVault.deposit(1000e6, receiver)
    function test_Gas_VaultDeposit() public {
        vm.prank(underwriter);
        uint256 gasBefore = gasleft();
        vault.deposit(1000e6, underwriter);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("2. vault.deposit() gas:", gasUsed);
    }

    /// @notice Operation 3: UnderwriterVault.withdraw(1000e6, receiver, owner)
    function test_Gas_VaultWithdraw() public {
        // First deposit so there's something to withdraw
        vm.prank(underwriter);
        vault.deposit(2000e6, underwriter);

        vm.prank(underwriter);
        uint256 gasBefore = gasleft();
        vault.withdraw(1000e6, underwriter, underwriter);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("3. vault.withdraw() gas:", gasUsed);
    }

    /// @notice Operation 4: InsurancePool.purchasePolicy(typeId, 1000e6, 30 days)
    function test_Gas_PurchasePolicy() public {
        vm.prank(policyHolder);
        uint256 gasBefore = gasleft();
        pool.purchasePolicy(POLICY_TYPE, 1000e6, 30 days);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("4. purchasePolicy() gas:", gasUsed);
    }

    /// @notice Operation 5: InsurancePool.processClaim(policyId)
    function test_Gas_ProcessClaim() public {
        // Setup: purchase and trigger a policy
        vm.prank(policyHolder);
        uint256 policyId = pool.purchasePolicy(POLICY_TYPE, 1000e6, 30 days);

        vm.prank(deployer);
        pool.triggerPolicy(policyId);

        vm.prank(deployer);
        uint256 gasBefore = gasleft();
        pool.processClaim(policyId);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("5. processClaim() gas:", gasUsed);
    }

    /// @notice Operation 6: CollateralManager.liquidate(underwriter, liquidator)
    function test_Gas_Liquidate() public {
        // Setup: create an undercollateralized position
        // Deposit small collateral as a separate underwriter
        address badUnderwriter = makeAddr("badUnderwriter");
        usdc.mint(badUnderwriter, 10_000e6);
        vm.startPrank(badUnderwriter);
        usdc.approve(address(cm), type(uint256).max);
        cm.depositCollateral(10_000e6);
        vm.stopPrank();

        // Grant POOL_ROLE to test contract so we can manipulate exposure
        bytes32 poolRole = cm.POOL_ROLE();
        vm.prank(deployer);
        cm.grantRole(poolRole, address(this));

        // Increase exposure to max LTV (75%)
        cm.increaseExposure(badUnderwriter, 7500e6);

        // To make the position liquidatable, we need healthFactor < 8500.
        // Currently: HF = 10000 * 10000 / 7500 = 13333 (healthy).
        // We use vm.store to directly set a higher exposure, simulating market conditions
        // that would push the position beyond the liquidation threshold.
        // collateralBalances mapping is at storage slot keccak256(abi.encode(key, baseSlot))
        // CollateralManager layout: slot 0=AccessControl, ... collateralBalances is after role storage.
        // Simpler: decrease exposure first, then use vm.store on exposure mapping.
        cm.decreaseExposure(badUnderwriter, 7500e6);

        // Set exposure directly to 50000e6 while collateral is only 10000e6
        // HF = 10000 * 10000 / 50000 = 2000 < 8500 — liquidatable
        // Find storage slots via forge inspect
        // coverageExposure mapping is at slot 3 (see: forge inspect CollateralManager storage-layout)
        bytes32 exposureSlot = keccak256(abi.encode(badUnderwriter, uint256(3)));
        vm.store(address(cm), exposureSlot, bytes32(uint256(50_000e6)));
        // Also update totalExposure at slot 5 to maintain consistency
        vm.store(address(cm), bytes32(uint256(5)), bytes32(uint256(50_000e6)));

        assertTrue(cm.isLiquidatable(badUnderwriter), "should be liquidatable");

        uint256 gasBefore = gasleft();
        cm.liquidate(badUnderwriter, liquidator);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("6. liquidate() gas:", gasUsed);
    }
}
