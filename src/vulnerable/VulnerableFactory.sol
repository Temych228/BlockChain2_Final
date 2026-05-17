// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title VulnerableFactory
/// @notice Deliberately vulnerable factory for the access control case study (§2.7).
///         The deploy function is PUBLIC with NO access control — anyone can deploy.
/// @dev DO NOT use in production.
contract VulnerableFactory {
    address[] public deployed;

    event Deployed(address indexed addr);

    /// @notice VULNERABLE — no access control, anyone can deploy arbitrary bytecode.
    function deploy(bytes memory bytecode) external returns (address addr) {
        require(bytecode.length > 0, "Empty bytecode");
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deploy failed");
        deployed.push(addr);
        emit Deployed(addr);
    }

    function getDeployed() external view returns (address[] memory) {
        return deployed;
    }
}

/// @title FixedFactory
/// @notice Same functionality as VulnerableFactory but with proper AccessControl.
///         Only DEPLOYER_ROLE can call deploy(). Mandatory fix for §2.7.
contract FixedFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    address[] public deployed;

    event Deployed(address indexed addr);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
    }

    /// @notice FIXED — only DEPLOYER_ROLE can deploy.
    function deploy(bytes memory bytecode) external onlyRole(DEPLOYER_ROLE) returns (address addr) {
        require(bytecode.length > 0, "Empty bytecode");
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "Deploy failed");
        deployed.push(addr);
        emit Deployed(addr);
    }

    function getDeployed() external view returns (address[] memory) {
        return deployed;
    }
}
