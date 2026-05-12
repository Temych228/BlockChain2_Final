// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PolicyFactory} from "../src/PolicyFactory.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @dev Minimal contract deployed via the factory for testing.
contract DummyPolicy {
    uint256 public value;

    constructor(uint256 _val) {
        value = _val;
    }
}

contract PolicyFactoryTest is Test {
    PolicyFactory public factory;

    address public admin;
    address public alice;

    bytes internal dummyBytecode;

    function setUp() public {
        admin = makeAddr("admin");
        alice = makeAddr("alice");

        vm.prank(admin);
        factory = new PolicyFactory(admin);

        dummyBytecode = abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(42));
    }

    // ─── Deployment
    // ──────────────────────────────────────────────

    function test_AdminHasRoles() public view {
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin));
    }

    function test_InitialDeployedPoliciesEmpty() public view {
        address[] memory policies = factory.getDeployedPolicies();
        assertEq(policies.length, 0);
    }

    // ─── CREATE (vanilla)
    // ────────────────────────────────────────

    function test_DeployVanilla_Success() public {
        // Act
        vm.prank(admin);
        address deployed = factory.deployPolicyTypeVanilla(dummyBytecode);

        // Assert: valid address returned, code exists
        assertTrue(deployed != address(0));
        assertTrue(deployed.code.length > 0);
        assertEq(DummyPolicy(deployed).value(), 42);
    }

    function test_DeployVanilla_EmitEvent() public {
        // Act & Assert: event emitted with salt=0
        vm.prank(admin);
        vm.expectEmit(false, true, false, false);
        emit PolicyFactory.PolicyTypeDeployed(address(0), bytes32(0));
        factory.deployPolicyTypeVanilla(dummyBytecode);
    }

    function test_DeployVanilla_GrowsDeployedArray() public {
        // Act: deploy twice
        vm.startPrank(admin);
        factory.deployPolicyTypeVanilla(dummyBytecode);
        factory.deployPolicyTypeVanilla(abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(99)));
        vm.stopPrank();

        // Assert
        address[] memory policies = factory.getDeployedPolicies();
        assertEq(policies.length, 2);
    }

    function test_DeployVanilla_RevertWithoutRole() public {
        // Arrange: cache role before prank
        bytes32 role = factory.FACTORY_ADMIN_ROLE();

        // Act & Assert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        factory.deployPolicyTypeVanilla(dummyBytecode);
    }

    function test_DeployVanilla_RevertEmptyBytecode() public {
        // Act & Assert
        vm.prank(admin);
        vm.expectRevert(PolicyFactory.EmptyBytecode.selector);
        factory.deployPolicyTypeVanilla("");
    }

    // ─── CREATE2 (deterministic)
    // ─────────────────────────────────

    function test_DeployDeterministic_Success() public {
        // Arrange
        bytes32 salt = keccak256("policy-type-1");

        // Act
        vm.prank(admin);
        address deployed = factory.deployPolicyTypeDeterministic(dummyBytecode, salt);

        // Assert
        assertTrue(deployed != address(0));
        assertTrue(deployed.code.length > 0);
        assertEq(DummyPolicy(deployed).value(), 42);
    }

    function test_DeployDeterministic_AddressPredictionMatches() public {
        // Arrange
        bytes32 salt = keccak256("deterministic-salt");

        // Act: predict address, then deploy
        address predicted = factory.computeAddress(dummyBytecode, salt);
        vm.prank(admin);
        address actual = factory.deployPolicyTypeDeterministic(dummyBytecode, salt);

        // Assert: predicted == actual
        assertEq(predicted, actual);
    }

    function test_DeployDeterministic_EmitEvent() public {
        // Arrange
        bytes32 salt = keccak256("event-salt");

        // Act & Assert
        vm.prank(admin);
        vm.expectEmit(false, true, false, false);
        emit PolicyFactory.PolicyTypeDeployed(address(0), salt);
        factory.deployPolicyTypeDeterministic(dummyBytecode, salt);
    }

    function test_DeployDeterministic_DuplicateSaltReverts() public {
        // Arrange
        bytes32 salt = keccak256("one-time-salt");

        vm.startPrank(admin);
        factory.deployPolicyTypeDeterministic(dummyBytecode, salt);

        // Act & Assert: same salt again reverts
        vm.expectRevert(abi.encodeWithSelector(PolicyFactory.SaltAlreadyUsed.selector, salt));
        factory.deployPolicyTypeDeterministic(dummyBytecode, salt);
        vm.stopPrank();
    }

    function test_DeployDeterministic_RevertWithoutRole() public {
        // Arrange: cache role before prank
        bytes32 salt = keccak256("unauthorized");
        bytes32 role = factory.FACTORY_ADMIN_ROLE();

        // Act & Assert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role));
        factory.deployPolicyTypeDeterministic(dummyBytecode, salt);
    }

    function test_DeployDeterministic_RevertEmptyBytecode() public {
        // Act & Assert
        vm.prank(admin);
        vm.expectRevert(PolicyFactory.EmptyBytecode.selector);
        factory.deployPolicyTypeDeterministic("", keccak256("salt"));
    }

    // ─── getDeployedPolicies
    // ─────────────────────────────────────

    function test_GetDeployedPolicies_MixedDeploys() public {
        // Act: mix of CREATE and CREATE2
        vm.startPrank(admin);
        address a1 = factory.deployPolicyTypeVanilla(dummyBytecode);
        address a2 = factory.deployPolicyTypeDeterministic(
            abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(7)), keccak256("s1")
        );
        address a3 = factory.deployPolicyTypeVanilla(abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(8)));
        vm.stopPrank();

        // Assert
        address[] memory policies = factory.getDeployedPolicies();
        assertEq(policies.length, 3);
        assertEq(policies[0], a1);
        assertEq(policies[1], a2);
        assertEq(policies[2], a3);
    }

    // ─── computeAddress
    // ──────────────────────────────────────────

    function test_ComputeAddress_DifferentSaltsDifferentAddresses() public view {
        // Arrange
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        // Act
        address addr1 = factory.computeAddress(dummyBytecode, salt1);
        address addr2 = factory.computeAddress(dummyBytecode, salt2);

        // Assert: different salts yield different addresses
        assertTrue(addr1 != addr2);
    }

    function test_ComputeAddress_DifferentBytecodeDifferentAddresses() public view {
        // Arrange
        bytes32 salt = keccak256("same-salt");
        bytes memory bytecode2 = abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(99));

        // Act
        address addr1 = factory.computeAddress(dummyBytecode, salt);
        address addr2 = factory.computeAddress(bytecode2, salt);

        // Assert
        assertTrue(addr1 != addr2);
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_DeployDeterministic_PredictionAlwaysMatches(bytes32 salt) public {
        // Arrange: predict
        address predicted = factory.computeAddress(dummyBytecode, salt);

        // Act: deploy
        vm.prank(admin);
        address actual = factory.deployPolicyTypeDeterministic(dummyBytecode, salt);

        // Assert
        assertEq(predicted, actual);
    }

    function testFuzz_DeployVanilla_AlwaysReturnsValidAddress(uint256 constructorArg) public {
        // Arrange
        bytes memory bytecode = abi.encodePacked(type(DummyPolicy).creationCode, abi.encode(constructorArg));

        // Act
        vm.prank(admin);
        address deployed = factory.deployPolicyTypeVanilla(bytecode);

        // Assert
        assertTrue(deployed != address(0));
        assertEq(DummyPolicy(deployed).value(), constructorArg);
    }
}
