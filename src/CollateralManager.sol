// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CollateralManager
/// @notice Lending-pool-style contract managing underwriter collateral positions.
///         Implements LTV ratio, health factor, and liquidation mechanics.
///         This is the mandatory DeFi primitive for Option E (built from scratch, no forks).
/// @dev All ERC-20 interactions use SafeERC20. All custom errors (no string reverts).
///      Follows CEI pattern in every state-changing function.
contract CollateralManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Role granted to InsurancePool for managing coverage exposure.
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");

    /// @notice The collateral token (USDC).
    IERC20 public immutable collateralToken;

    /// @notice Maximum loan-to-value ratio: 75% (in basis points).
    uint256 public constant MAX_LTV = 7500;

    /// @notice Liquidation threshold: 85% (in basis points).
    ///         When health factor drops below this, the position is liquidatable.
    uint256 public constant LIQUIDATION_THRESHOLD = 8500;

    /// @notice Liquidation bonus: 5% reward for liquidators (in basis points).
    uint256 public constant LIQUIDATION_BONUS = 500;

    /// @notice Basis points denominator (100%).
    uint256 public constant BASIS_POINTS = 10_000;

    /// @notice USDC collateral balance per underwriter.
    mapping(address => uint256) public collateralBalances;

    /// @notice Total coverage exposure per underwriter.
    mapping(address => uint256) public coverageExposure;

    /// @notice Aggregate collateral across all underwriters.
    uint256 public totalCollateral;

    /// @notice Aggregate coverage exposure across all underwriters.
    uint256 public totalExposure;

    // ─── Events
    // ──────────────────────────────────────────────────

    event CollateralDeposited(address indexed underwriter, uint256 amount);
    event CollateralWithdrawn(address indexed underwriter, uint256 amount);
    event ExposureIncreased(address indexed underwriter, uint256 coverageAmount);
    event ExposureDecreased(address indexed underwriter, uint256 coverageAmount);
    event Liquidated(address indexed underwriter, address indexed liquidator, uint256 seizedCollateral);

    // ─── Custom Errors
    // ───────────────────────────────────────────

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientHealthFactor();
    error ExposureLimitExceeded();
    error NotLiquidatable();
    error InsufficientCollateral();

    /// @notice Deploys the CollateralManager with the specified collateral token.
    /// @param _collateralToken The USDC token address.
    /// @param admin The address receiving DEFAULT_ADMIN_ROLE.
    constructor(IERC20 _collateralToken, address admin) {
        if (address(_collateralToken) == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();
        collateralToken = _collateralToken;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Deposits USDC collateral for the caller.
    /// @dev CEI: checks amount > 0 → updates balances → transfers tokens.
    /// @param amount The USDC amount to deposit.
    function depositCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        // Effects
        collateralBalances[msg.sender] += amount;
        totalCollateral += amount;

        // Interactions
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    /// @notice Withdraws USDC collateral, subject to health factor checks.
    /// @dev CEI: checks health factor after simulated withdrawal → updates balances → transfers.
    ///      Reverts with InsufficientHealthFactor if withdrawal would breach MAX_LTV.
    /// @param amount The USDC amount to withdraw.
    function withdrawCollateral(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (collateralBalances[msg.sender] < amount) revert InsufficientCollateral();

        // Check: simulate post-withdrawal health factor
        uint256 newCollateral = collateralBalances[msg.sender] - amount;
        uint256 exposure = coverageExposure[msg.sender];
        if (exposure > 0) {
            uint256 postHealthFactor = (newCollateral * BASIS_POINTS) / exposure;
            if (postHealthFactor < LIQUIDATION_THRESHOLD) revert InsufficientHealthFactor();
        }

        // Effects
        collateralBalances[msg.sender] = newCollateral;
        totalCollateral -= amount;

        // Interactions
        collateralToken.safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Increases an underwriter's coverage exposure. Only callable by InsurancePool.
    /// @dev Checks that new exposure doesn't exceed MAX_LTV of the underwriter's collateral.
    /// @param underwriter The underwriter address.
    /// @param coverageAmount The coverage amount to add.
    function increaseExposure(address underwriter, uint256 coverageAmount) external onlyRole(POOL_ROLE) {
        if (coverageAmount == 0) revert ZeroAmount();

        uint256 newExposure = coverageExposure[underwriter] + coverageAmount;
        uint256 maxExposure = (collateralBalances[underwriter] * MAX_LTV) / BASIS_POINTS;
        if (newExposure > maxExposure) revert ExposureLimitExceeded();

        coverageExposure[underwriter] = newExposure;
        totalExposure += coverageAmount;

        emit ExposureIncreased(underwriter, coverageAmount);
    }

    /// @notice Decreases an underwriter's coverage exposure. Only callable by InsurancePool.
    /// @param underwriter The underwriter address.
    /// @param coverageAmount The coverage amount to remove.
    function decreaseExposure(address underwriter, uint256 coverageAmount) external onlyRole(POOL_ROLE) {
        if (coverageAmount == 0) revert ZeroAmount();

        coverageExposure[underwriter] -= coverageAmount;
        totalExposure -= coverageAmount;

        emit ExposureDecreased(underwriter, coverageAmount);
    }

    /// @notice Returns the health factor for an underwriter.
    /// @dev healthFactor = (collateral * BASIS_POINTS) / max(exposure, 1).
    ///      Returns type(uint256).max if exposure is 0 (fully healthy).
    /// @param underwriter The underwriter address.
    /// @return The health factor in basis points.
    function healthFactor(address underwriter) public view returns (uint256) {
        uint256 exposure = coverageExposure[underwriter];
        if (exposure == 0) return type(uint256).max;
        return (collateralBalances[underwriter] * BASIS_POINTS) / exposure;
    }

    /// @notice Checks if an underwriter position is liquidatable.
    /// @param underwriter The underwriter address.
    /// @return True if healthFactor < LIQUIDATION_THRESHOLD.
    function isLiquidatable(address underwriter) public view returns (bool) {
        return healthFactor(underwriter) < LIQUIDATION_THRESHOLD;
    }

    /// @notice Liquidates an undercollateralized underwriter position.
    /// @dev CEI: checks isLiquidatable → updates collateral/exposure → transfers seized amount.
    ///      The liquidator receives the seized collateral plus a LIQUIDATION_BONUS.
    /// @param underwriter The underwriter to liquidate.
    /// @param liquidator The address receiving the seized collateral.
    function liquidate(address underwriter, address liquidator) external nonReentrant {
        // Checks
        if (!isLiquidatable(underwriter)) revert NotLiquidatable();

        // Calculate seized collateral = min(exposure * LIQUIDATION_BONUS / BASIS_POINTS, balance)
        uint256 exposure = coverageExposure[underwriter];
        uint256 bonus = (exposure * LIQUIDATION_BONUS) / BASIS_POINTS;
        uint256 seized = bonus < collateralBalances[underwriter] ? bonus : collateralBalances[underwriter];

        // Effects
        collateralBalances[underwriter] -= seized;
        totalCollateral -= seized;
        totalExposure -= exposure;
        coverageExposure[underwriter] = 0;

        // Interactions
        collateralToken.safeTransfer(liquidator, seized);

        emit Liquidated(underwriter, liquidator, seized);
    }

    /// @notice Returns the current pool utilization rate.
    /// @dev utilizationRate = totalExposure * 1e18 / max(totalCollateral, 1).
    /// @return The utilization ratio scaled to 1e18 (0 = 0%, 1e18 = 100%).
    function utilizationRate() public view returns (uint256) {
        if (totalCollateral == 0) return 0;
        return (totalExposure * 1e18) / totalCollateral;
    }

    /// @notice Pauses all deposit/withdraw operations.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all operations.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
