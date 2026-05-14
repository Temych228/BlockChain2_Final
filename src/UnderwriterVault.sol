// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title UnderwriterVault
/// @notice ERC-4626 tokenized vault where underwriters deposit USDC collateral and earn
///         yield from insurance premiums collected by the protocol.
/// @dev Rounding convention (ERC-4626 security):
///      - deposit/mint: rounds DOWN (user receives fewer shares — favors vault)
///      - withdraw/redeem: rounds UP (user pays more assets per share — favors vault)
///      This ensures no "free money" can be extracted via rounding exploits.
///      All ERC-20 transfers use SafeERC20 (no raw transfer/transferFrom).
contract UnderwriterVault is ERC4626, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role that allows depositing collected premiums into the vault.
    ///         Granted to InsurancePool.
    bytes32 public constant PREMIUM_DEPOSITOR_ROLE = keccak256("PREMIUM_DEPOSITOR_ROLE");

    /// @notice Emitted when premiums are deposited into the vault.
    /// @param amount The USDC amount deposited as premiums.
    event PremiumsDeposited(uint256 amount);

    /// @notice Thrown when a zero amount is provided.
    error ZeroAmount();

    /// @notice Thrown when a zero address is provided.
    error ZeroAddress();

    /// @notice Deploys the vault with the underlying USDC asset.
    /// @param asset_ The USDC token address.
    /// @param admin The address receiving DEFAULT_ADMIN_ROLE.
    constructor(IERC20 asset_, address admin) ERC20("InsureDAO Vault Share", "ivUSDC") ERC4626(asset_) {
        if (address(asset_) == address(0)) revert ZeroAddress();
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Deposits collected premiums into the vault, increasing totalAssets.
    /// @dev Only callable by InsurancePool (PREMIUM_DEPOSITOR_ROLE). The premium USDC
    ///      is transferred from the caller into the vault. This increases the share price
    ///      for all existing depositors proportionally.
    /// @param amount The USDC premium amount to deposit.
    function depositPremiums(uint256 amount) external onlyRole(PREMIUM_DEPOSITOR_ROLE) {
        if (amount == 0) revert ZeroAmount();
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        emit PremiumsDeposited(amount);
    }

    /// @inheritdoc ERC4626
    /// @dev Overridden to add whenNotPaused and nonReentrant modifiers. CEI pattern.
    function deposit(uint256 assets, address receiver) public override whenNotPaused nonReentrant returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @inheritdoc ERC4626
    /// @dev Overridden to add whenNotPaused and nonReentrant modifiers. CEI pattern.
    function mint(uint256 shares, address receiver) public override whenNotPaused nonReentrant returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @inheritdoc ERC4626
    /// @dev Overridden to add whenNotPaused and nonReentrant modifiers. CEI pattern.
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /// @inheritdoc ERC4626
    /// @dev Overridden to add whenNotPaused and nonReentrant modifiers. CEI pattern.
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    /// @notice Pauses all deposit/withdraw/mint/redeem operations.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE.
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all vault operations.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @inheritdoc ERC4626
    /// @dev Returns 0 — no virtual offset. Rounding is handled by the base ERC4626
    ///      implementation: deposit/mint round DOWN, withdraw/redeem round UP.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 0;
    }
}
