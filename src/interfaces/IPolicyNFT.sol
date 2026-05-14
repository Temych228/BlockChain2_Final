// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPolicyNFT
/// @notice Interface for the ERC-1155 policy token contract.
interface IPolicyNFT {
    /// @notice Mints policy tokens to a holder.
    /// @param to The recipient address.
    /// @param policyTypeId The policy type tokenId.
    /// @param amount The number of tokens to mint.
    /// @param data Additional data for the ERC-1155 receiver hook.
    function mintPolicy(address to, uint256 policyTypeId, uint256 amount, bytes memory data) external;

    /// @notice Burns policy tokens from a holder on claim settlement.
    /// @param from The address whose tokens are burned.
    /// @param policyTypeId The policy type tokenId.
    /// @param amount The number of tokens to burn.
    function burnPolicy(address from, uint256 policyTypeId, uint256 amount) external;
}
