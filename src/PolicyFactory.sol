// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PolicyFactory
/// @notice Factory contract that deploys new policy type contracts using both CREATE and CREATE2.
/// @dev Satisfies the Factory design pattern requirement (§3.1) with deterministic and
///      non-deterministic deployment options. Only FACTORY_ADMIN_ROLE can deploy.
contract PolicyFactory is AccessControl, ReentrancyGuard {
    /// @notice Role required to deploy new policy type contracts.
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

    /// @notice Array of all deployed policy type contract addresses.
    address[] private _deployedPolicies;

    /// @notice Tracks used CREATE2 salts to prevent duplicate deployments.
    mapping(bytes32 => bool) private _usedSalts;

    /// @notice Emitted when a new policy type contract is deployed.
    /// @param deployed The address of the newly deployed contract.
    /// @param salt The CREATE2 salt used (bytes32(0) for CREATE deployments).
    event PolicyTypeDeployed(address indexed deployed, bytes32 indexed salt);

    /// @notice Thrown when a CREATE or CREATE2 deployment returns the zero address.
    error DeploymentFailed();

    /// @notice Thrown when a CREATE2 salt has already been used.
    /// @param salt The duplicate salt.
    error SaltAlreadyUsed(bytes32 salt);

    /// @notice Thrown when empty bytecode is provided for deployment.
    error EmptyBytecode();

    /// @notice Deploys the factory and grants FACTORY_ADMIN_ROLE and DEFAULT_ADMIN_ROLE to admin.
    /// @param admin The address receiving factory admin privileges.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FACTORY_ADMIN_ROLE, admin);
    }

    /// @notice Deploys a contract using the CREATE opcode (non-deterministic address).
    /// @dev The deployed address depends on this factory's nonce.
    /// @param bytecode The full creation bytecode of the contract to deploy.
    /// @return deployed The address of the newly deployed contract.
    function deployPolicyTypeVanilla(bytes memory bytecode)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
        nonReentrant
        returns (address deployed)
    {
        if (bytecode.length == 0) revert EmptyBytecode();

        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        if (deployed == address(0)) revert DeploymentFailed();

        _deployedPolicies.push(deployed);
        emit PolicyTypeDeployed(deployed, bytes32(0));
    }

    /// @notice Deploys a contract using the CREATE2 opcode (deterministic address).
    /// @dev The address can be predicted via computeAddress() before deployment.
    ///      Each salt can only be used once.
    /// @param bytecode The full creation bytecode of the contract to deploy.
    /// @param salt A unique salt for deterministic address derivation.
    /// @return deployed The address of the newly deployed contract.
    function deployPolicyTypeDeterministic(bytes memory bytecode, bytes32 salt)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
        nonReentrant
        returns (address deployed)
    {
        if (bytecode.length == 0) revert EmptyBytecode();
        if (_usedSalts[salt]) revert SaltAlreadyUsed(salt);

        _usedSalts[salt] = true;

        assembly {
            deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (deployed == address(0)) revert DeploymentFailed();

        _deployedPolicies.push(deployed);
        emit PolicyTypeDeployed(deployed, salt);
    }

    /// @notice Predicts the CREATE2 deployment address for given bytecode and salt.
    /// @param bytecode The full creation bytecode.
    /// @param salt The CREATE2 salt.
    /// @return predicted The address where the contract would be deployed.
    function computeAddress(bytes memory bytecode, bytes32 salt) external view returns (address predicted) {
        predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)))))
        );
    }

    /// @notice Returns all deployed policy type contract addresses.
    /// @return An array of deployed contract addresses.
    function getDeployedPolicies() external view returns (address[] memory) {
        return _deployedPolicies;
    }
}
