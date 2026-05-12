// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public token;

    address public deployer;
    address public alice;
    address public bob;
    address public charlie;

    uint256 internal constant INITIAL_SUPPLY = 10_000_000e18;
    uint256 internal constant MAX_SUPPLY = 100_000_000e18;

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.prank(deployer);
        token = new GovernanceToken(deployer);
    }

    // ─── Deployment
    // ──────────────────────────────────────────────

    function test_InitialSupply() public view {
        // Assert: deployer receives initial 10M supply
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "InsureDAO");
        assertEq(token.symbol(), "IDAO");
    }

    function test_OwnerIsDeployer() public view {
        assertEq(token.owner(), deployer);
    }

    // ─── Minting
    // ─────────────────────────────────────────────────

    function test_Mint_Success() public {
        // Arrange
        uint256 mintAmount = 1_000_000e18;

        // Act
        vm.prank(deployer);
        token.mint(alice, mintAmount);

        // Assert
        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function test_Mint_RevertWhenNotOwner() public {
        // Arrange
        uint256 mintAmount = 1000e18;

        // Act & Assert: non-owner cannot mint
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, mintAmount);
    }

    function test_Mint_RevertWhenExceedsMaxSupply() public {
        // Arrange: try to mint more than MAX_SUPPLY - INITIAL_SUPPLY
        uint256 remaining = MAX_SUPPLY - INITIAL_SUPPLY;
        uint256 overAmount = remaining + 1;

        // Act & Assert
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ExceedsMaxSupply.selector, overAmount, remaining));
        token.mint(alice, overAmount);
    }

    function test_Mint_ExactlyToMaxSupply() public {
        // Arrange
        uint256 remaining = MAX_SUPPLY - INITIAL_SUPPLY;

        // Act: mint exactly to the cap
        vm.prank(deployer);
        token.mint(alice, remaining);

        // Assert
        assertEq(token.totalSupply(), MAX_SUPPLY);
    }

    function test_Mint_RevertOnOneWeiOverCap() public {
        // Arrange: mint to cap first
        uint256 remaining = MAX_SUPPLY - INITIAL_SUPPLY;
        vm.prank(deployer);
        token.mint(alice, remaining);

        // Act & Assert: 1 more wei reverts
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(GovernanceToken.ExceedsMaxSupply.selector, 1, 0));
        token.mint(alice, 1);
    }

    // ─── Burning
    // ─────────────────────────────────────────────────

    function test_Burn_Success() public {
        // Arrange
        uint256 burnAmount = 1_000_000e18;

        // Act: deployer burns own tokens
        vm.prank(deployer);
        token.burn(burnAmount);

        // Assert
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function test_BurnFrom_WithAllowance() public {
        // Arrange: deployer approves alice to burn
        uint256 burnAmount = 500_000e18;
        vm.prank(deployer);
        token.approve(alice, burnAmount);

        // Act
        vm.prank(alice);
        token.burnFrom(deployer, burnAmount);

        // Assert
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - burnAmount);
    }

    // ─── Transfer
    // ────────────────────────────────────────────────

    function test_Transfer_Success() public {
        // Arrange
        uint256 amount = 100e18;

        // Act
        vm.prank(deployer);
        token.transfer(alice, amount);

        // Assert
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
    }

    function test_TransferFrom_WithApproval() public {
        // Arrange
        uint256 amount = 200e18;
        vm.prank(deployer);
        token.approve(alice, amount);

        // Act
        vm.prank(alice);
        token.transferFrom(deployer, bob, amount);

        // Assert
        assertEq(token.balanceOf(bob), amount);
    }

    // ─── Delegation & Voting
    // ─────────────────────────────────────

    function test_Delegate_VotingPowerUpdates() public {
        // Arrange: transfer tokens to alice
        vm.prank(deployer);
        token.transfer(alice, 1000e18);

        // Act: alice delegates to herself
        vm.prank(alice);
        token.delegate(alice);

        // Assert: voting power equals balance after delegation
        assertEq(token.getVotes(alice), 1000e18);
    }

    function test_Delegate_ToAnotherUser() public {
        // Arrange
        vm.prank(deployer);
        token.transfer(alice, 5000e18);

        // Act: alice delegates to bob
        vm.prank(alice);
        token.delegate(bob);

        // Assert
        assertEq(token.getVotes(bob), 5000e18);
        assertEq(token.getVotes(alice), 0);
    }

    function test_Delegate_PastVotesCheckpoint() public {
        // Arrange
        vm.prank(deployer);
        token.transfer(alice, 3000e18);

        vm.prank(alice);
        token.delegate(alice);

        uint256 snapshotBlock = block.number;
        vm.roll(snapshotBlock + 1);

        // Act: transfer more after checkpoint
        vm.prank(deployer);
        token.transfer(alice, 2000e18);

        // Assert: past votes at snapshotBlock reflect the earlier balance
        assertEq(token.getPastVotes(alice, snapshotBlock), 3000e18);
        // Current votes reflect new balance
        assertEq(token.getVotes(alice), 5000e18);
    }

    // ─── Permit (EIP-2612)
    // ───────────────────────────────────────

    function test_Permit_Success() public {
        // Arrange
        uint256 ownerKey = 0xA11CE;
        address owner = vm.addr(ownerKey);
        uint256 amount = 1000e18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(deployer);
        token.transfer(owner, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, owner, alice, amount, token.nonces(owner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        // Act
        token.permit(owner, alice, amount, deadline, v, r, s);

        // Assert
        assertEq(token.allowance(owner, alice), amount);
        assertEq(token.nonces(owner), 1);
    }

    function test_Permit_RevertExpiredDeadline() public {
        // Arrange
        uint256 ownerKey = 0xA11CE;
        address owner = vm.addr(ownerKey);
        uint256 deadline = block.timestamp - 1;

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, owner, alice, 100e18, 0, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        // Act & Assert
        vm.expectRevert();
        token.permit(owner, alice, 100e18, deadline, v, r, s);
    }

    // ─── Ownership
    // ───────────────────────────────────────────────

    function test_OwnershipTransfer_TwoStep() public {
        // Arrange & Act: deployer initiates transfer to alice
        vm.prank(deployer);
        token.transferOwnership(alice);

        // Assert: pending owner is alice, current owner is still deployer
        assertEq(token.pendingOwner(), alice);
        assertEq(token.owner(), deployer);

        // Act: alice accepts ownership
        vm.prank(alice);
        token.acceptOwnership();

        // Assert
        assertEq(token.owner(), alice);
    }

    function test_OwnershipTransfer_RevertNonPendingAccept() public {
        // Arrange
        vm.prank(deployer);
        token.transferOwnership(alice);

        // Act & Assert: bob cannot accept
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        token.acceptOwnership();
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_Mint_RespectsCap(uint256 amount) public {
        // Arrange
        uint256 remaining = MAX_SUPPLY - token.totalSupply();
        amount = bound(amount, 1, remaining);

        // Act
        vm.prank(deployer);
        token.mint(alice, amount);

        // Assert
        assertLe(token.totalSupply(), MAX_SUPPLY);
    }

    function testFuzz_TransferPreservesTotalSupply(uint256 amount) public {
        // Arrange
        amount = bound(amount, 1, token.balanceOf(deployer));
        uint256 supplyBefore = token.totalSupply();

        // Act
        vm.prank(deployer);
        token.transfer(alice, amount);

        // Assert: total supply unchanged
        assertEq(token.totalSupply(), supplyBefore);
    }
}
