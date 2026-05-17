// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title VulnerablePool
/// @notice Deliberately vulnerable pool for the reentrancy case study (§2.6).
///         Contains a classic reentrancy bug: ETH is sent to the caller BEFORE
///         the balance mapping is zeroed.
/// @dev DO NOT use in production.
contract VulnerablePool {
    mapping(address => uint256) public deposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    /// @notice VULNERABLE — sends ETH before updating state.
    function withdraw() external {
        uint256 bal = deposits[msg.sender];
        require(bal > 0, "Nothing to withdraw");

        // BUG: Interaction before Effect — attacker's receive() re-enters withdraw()
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "Transfer failed");

        deposits[msg.sender] = 0; // too late — already re-entered
    }

    receive() external payable {}
}

/// @title FixedPool
/// @notice Same functionality as VulnerablePool but with the reentrancy bug fixed
///         using the CEI pattern (Effects before Interactions).
contract FixedPool {
    mapping(address => uint256) public deposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    /// @notice FIXED — zeroes balance BEFORE sending ETH.
    function withdraw() external {
        uint256 bal = deposits[msg.sender];
        require(bal > 0, "Nothing to withdraw");

        deposits[msg.sender] = 0; // Effect first

        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "Transfer failed");
    }

    receive() external payable {}
}
