// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUnderwriterVault} from "./interfaces/IUnderwriterVault.sol";
import {ICollateralManager} from "./interfaces/ICollateralManager.sol";
import {IPolicyNFT} from "./interfaces/IPolicyNFT.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {PremiumMath} from "./libraries/PremiumMath.sol";

/// @title InsurancePool (V1)
/// @notice Core UUPS-upgradeable contract orchestrating the insurance protocol.
///         Manages policy types, policy purchases, claim triggers, and claim payouts.
/// @dev Storage layout is critical for upgrade safety — every slot is documented.
///      Uses OZ v5 upgradeable contracts. ReentrancyGuard is stateless in OZ v5
///      so the non-upgradeable version is used directly.
///
///      === STORAGE LAYOUT (V1) ===
///      Slots 0–49:  Reserved for OZ upgradeable base contracts
///                    (Initializable, UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable)
///      Slot  50:    vault (IUnderwriterVault)
///      Slot  51:    collateralManager (ICollateralManager)
///      Slot  52:    policyNFT (IPolicyNFT)
///      Slot  53:    oracle (IOracle)
///      Slot  54:    usdc (IERC20)
///      Slot  55:    totalPremiumsCollected (uint256)
///      Slot  56:    policyTypes mapping
///      Slot  57:    policies mapping
///      Slot  58:    nextPolicyId (uint256)
///      Slots 59–101: __gap[43] reserved for V2+ upgrades
contract InsurancePool is UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Roles
    // ───────────────────────────────────────────────────

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant POLICY_MANAGER_ROLE = keccak256("POLICY_MANAGER_ROLE");
    bytes32 public constant CLAIM_PROCESSOR_ROLE = keccak256("CLAIM_PROCESSOR_ROLE");

    // ─── Enums & Structs
    // ─────────────────────────────────────────

    enum PolicyState {
        ACTIVE,
        TRIGGERED,
        CLAIMED,
        EXPIRED
    }

    struct PolicyType {
        uint256 maxCoverage;
        uint256 riskMultiplier; // scaled to 1e18 (1e18 = 1x)
        bool active;
    }

    struct Policy {
        address holder;
        uint256 policyTypeId;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 expiry;
        PolicyState state;
    }

    // ─── Storage (slot 50+)
    // ──────────────────────────────────────

    /// @notice The ERC-4626 vault holding underwriter collateral and premiums.
    IUnderwriterVault public vault; // slot 50

    /// @notice The lending-pool collateral manager.
    ICollateralManager public collateralManager; // slot 51

    /// @notice The ERC-1155 policy NFT contract.
    IPolicyNFT public policyNFT; // slot 52

    /// @notice The oracle adapter for price feeds.
    IOracle public oracle; // slot 53

    /// @notice The USDC token used for premiums and payouts.
    IERC20 public usdc; // slot 54

    /// @notice Cumulative premiums collected by the protocol.
    uint256 public totalPremiumsCollected; // slot 55

    /// @notice Registered policy types. typeId => PolicyType.
    mapping(uint256 => PolicyType) public policyTypes; // slot 56

    /// @notice Issued policies. policyId => Policy.
    mapping(uint256 => Policy) public policies; // slot 57

    /// @notice Auto-incrementing policy ID counter.
    uint256 public nextPolicyId; // slot 58

    /// @notice Reserved storage gap for future upgrades (V2, V3, etc.).
    uint256[43] private __gap; // slots 59–101

    // ─── Events
    // ──────────────────────────────────────────────────

    event PolicyPurchased(
        uint256 indexed policyId, address indexed holder, uint256 policyTypeId, uint256 coverageAmount, uint256 premium
    );
    event PolicyTriggered(uint256 indexed policyId);
    event ClaimProcessed(uint256 indexed policyId, address indexed holder, uint256 payoutAmount);
    event PolicyTypeAdded(uint256 indexed typeId, uint256 maxCoverage, uint256 riskMultiplier);

    // ─── Custom Errors
    // ───────────────────────────────────────────

    error ZeroAddress();
    error PolicyTypeInactive();
    error CoverageExceedsMax(uint256 requested, uint256 max);
    error DurationTooLong(uint256 requested, uint256 max);
    error InvalidPolicyState(PolicyState current, PolicyState expected);
    error PolicyExpired();

    // ─── Initializer
    // ─────────────────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the V1 proxy with all protocol dependencies and admin roles.
    /// @param _vault The UnderwriterVault address.
    /// @param _collateralManager The CollateralManager address.
    /// @param _policyNFT The PolicyNFT address.
    /// @param _oracle The oracle adapter address.
    /// @param _usdc The USDC token address.
    /// @param _admin The address receiving all admin roles.
    function initialize(
        address _vault,
        address _collateralManager,
        address _policyNFT,
        address _oracle,
        address _usdc,
        address _admin
    ) external initializer {
        if (
            _vault == address(0) || _collateralManager == address(0) || _policyNFT == address(0) || _usdc == address(0)
                || _admin == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __Pausable_init();

        vault = IUnderwriterVault(_vault);
        collateralManager = ICollateralManager(_collateralManager);
        policyNFT = IPolicyNFT(_policyNFT);
        oracle = IOracle(_oracle);
        usdc = IERC20(_usdc);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(POLICY_MANAGER_ROLE, _admin);
        _grantRole(CLAIM_PROCESSOR_ROLE, _admin);
    }

    // ─── Policy Type Management
    // ──────────────────────────────────

    /// @notice Registers a new policy type (or updates an existing one).
    /// @param typeId The policy type identifier.
    /// @param maxCoverage Maximum coverage amount for this type.
    /// @param riskMultiplier Risk multiplier scaled to 1e18.
    function addPolicyType(uint256 typeId, uint256 maxCoverage, uint256 riskMultiplier)
        external
        onlyRole(POLICY_MANAGER_ROLE)
    {
        policyTypes[typeId] = PolicyType({maxCoverage: maxCoverage, riskMultiplier: riskMultiplier, active: true});
        emit PolicyTypeAdded(typeId, maxCoverage, riskMultiplier);
    }

    // ─── Policy Purchase
    // ─────────────────────────────────────────

    /// @notice Purchases an insurance policy.
    /// @dev CEI pattern: checks → effects (state) → interactions (transfers, external calls).
    /// @param policyTypeId The type of policy to purchase.
    /// @param coverageAmount The desired coverage amount in USDC.
    /// @param duration The policy duration in seconds (max 365 days).
    /// @return policyId The ID of the newly created policy.
    function purchasePolicy(uint256 policyTypeId, uint256 coverageAmount, uint256 duration)
        external
        virtual
        nonReentrant
        whenNotPaused
        returns (uint256 policyId)
    {
        // ── Checks ──
        PolicyType storage pt = policyTypes[policyTypeId];
        if (!pt.active) revert PolicyTypeInactive();
        if (coverageAmount > pt.maxCoverage) revert CoverageExceedsMax(coverageAmount, pt.maxCoverage);
        if (duration > 365 days) revert DurationTooLong(duration, 365 days);

        uint256 utilization = collateralManager.utilizationRate();
        uint256 premium = PremiumMath.calculatePremium(coverageAmount, utilization, pt.riskMultiplier);

        // ── Effects ──
        policyId = nextPolicyId++;
        policies[policyId] = Policy({
            holder: msg.sender,
            policyTypeId: policyTypeId,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            expiry: block.timestamp + duration,
            state: PolicyState.ACTIVE
        });
        totalPremiumsCollected += premium;

        // ── Interactions ──
        if (premium > 0) {
            usdc.safeTransferFrom(msg.sender, address(this), premium);
            usdc.forceApprove(address(vault), premium);
            vault.depositPremiums(premium);
        }
        // Exposure is tracked at the pool level — all underwriters collectively back policies
        collateralManager.increaseExposure(address(this), coverageAmount);
        policyNFT.mintPolicy(msg.sender, policyTypeId, 1, "");

        emit PolicyPurchased(policyId, msg.sender, policyTypeId, coverageAmount, premium);
    }

    // ─── Claim Processing
    // ────────────────────────────────────────

    /// @notice Triggers a policy for claim processing (oracle/admin action).
    /// @dev Only callable by CLAIM_PROCESSOR_ROLE. Policy must be ACTIVE and not expired.
    /// @param policyId The policy ID to trigger.
    function triggerPolicy(uint256 policyId) external onlyRole(CLAIM_PROCESSOR_ROLE) {
        Policy storage p = policies[policyId];
        if (p.state != PolicyState.ACTIVE) revert InvalidPolicyState(p.state, PolicyState.ACTIVE);
        if (block.timestamp > p.expiry) revert PolicyExpired();

        p.state = PolicyState.TRIGGERED;

        emit PolicyTriggered(policyId);
    }

    /// @notice Processes a triggered claim, paying out coverage to the holder.
    /// @dev CEI: checks state → updates state → withdraws from vault → transfers to holder.
    /// @param policyId The policy ID to process.
    function processClaim(uint256 policyId) external nonReentrant onlyRole(CLAIM_PROCESSOR_ROLE) {
        Policy storage p = policies[policyId];

        // Checks
        if (p.state != PolicyState.TRIGGERED) revert InvalidPolicyState(p.state, PolicyState.TRIGGERED);

        // Effects
        p.state = PolicyState.CLAIMED;
        uint256 payout = p.coverageAmount;

        // Interactions
        vault.withdraw(payout, p.holder, address(this));
        collateralManager.decreaseExposure(address(this), payout);
        policyNFT.burnPolicy(p.holder, p.policyTypeId, 1);

        emit ClaimProcessed(policyId, p.holder, payout);
    }

    // ─── Admin
    // ───────────────────────────────────────────────────

    /// @notice Pauses all policy purchases and claim processing.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses all operations.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Returns the protocol version string.
    /// @return The version identifier.
    function getVersion() external pure virtual returns (string memory) {
        return "V1";
    }

    // ─── UUPS
    // ────────────────────────────────────────────────────

    /// @dev Restricts proxy upgrades to DEFAULT_ADMIN_ROLE.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
