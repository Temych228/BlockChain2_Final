// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IUnderwriterVault
/// @notice Interface for the ERC-4626 underwriter vault.
interface IUnderwriterVault {
    /// @notice Deposits collected premiums into the vault, increasing totalAssets for all shareholders.
    /// @param amount The USDC amount to deposit as premiums.
    function depositPremiums(uint256 amount) external;

    /// @notice ERC-4626 deposit: deposits assets and receives shares.
    /// @param assets The amount of underlying assets to deposit.
    /// @param receiver The address receiving the vault shares.
    /// @return shares The number of shares minted.
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @notice ERC-4626 withdraw: burns shares and returns assets.
    /// @param assets The amount of underlying assets to withdraw.
    /// @param receiver The address receiving the assets.
    /// @param owner The address whose shares are burned.
    /// @return shares The number of shares burned.
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /// @notice Returns the total underlying assets held by the vault.
    /// @return totalManagedAssets The total USDC balance.
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @notice Pauses all vault operations.
    function pause() external;

    /// @notice Unpauses all vault operations.
    function unpause() external;
}
