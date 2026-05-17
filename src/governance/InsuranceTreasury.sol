// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title InsuranceTreasury
/// @notice Holds collected protocol fees. Controlled ONLY by the TimelockController,
///         ensuring all fund movements require a successful governance vote + timelock delay.
/// @dev DEFAULT_ADMIN_ROLE is granted to the Timelock at deployment. The deployer
///      renounces admin after setup so that only governance proposals can withdraw.
///      ETH withdrawals use call{value:}("") — never .transfer() or .send() (§3.2).
contract InsuranceTreasury is AccessControl {
    using SafeERC20 for IERC20;

    /// @notice Emitted when the treasury receives ETH.
    event ETHReceived(address indexed sender, uint256 amount);

    /// @notice Emitted when ERC-20 tokens are withdrawn from the treasury.
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

    /// @notice Emitted when ETH is withdrawn from the treasury.
    event ETHWithdrawn(address indexed to, uint256 amount);

    /// @notice Thrown when a zero address is provided where one is not allowed.
    error ZeroAddress();

    /// @notice Thrown when an ETH transfer fails.
    error ETHTransferFailed();

    /// @notice Deploys the treasury with the given admin (should be the TimelockController).
    /// @param admin The address receiving DEFAULT_ADMIN_ROLE.
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Withdraws ERC-20 tokens from the treasury.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE (TimelockController).
    ///      Uses SafeERC20 for safe transfer handling.
    /// @param token The ERC-20 token address to withdraw.
    /// @param to The recipient address.
    /// @param amount The amount of tokens to withdraw.
    function withdrawERC20(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit ERC20Withdrawn(token, to, amount);
    }

    /// @notice Withdraws ETH from the treasury.
    /// @dev Only callable by DEFAULT_ADMIN_ROLE (TimelockController).
    ///      Uses low-level call instead of .transfer()/.send() to avoid
    ///      the 2300 gas stipend issue (§3.2 security requirement).
    /// @param to The recipient address.
    /// @param amount The amount of ETH (in wei) to withdraw.
    function withdrawETH(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        (bool success,) = to.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
        emit ETHWithdrawn(to, amount);
    }

    /// @notice Allows the treasury to receive ETH.
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
}
