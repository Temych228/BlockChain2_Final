// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PolicyNFT} from "../src/PolicyNFT.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract PolicyNFTTest is Test {
    PolicyNFT public nft;

    address public admin;
    address public minter;
    address public burner;
    address public alice;
    address public bob;

    string constant BASE_URI = "https://api.insuredao.io/policy/";

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.startPrank(admin);
        nft = new PolicyNFT(BASE_URI, admin);
        nft.grantRole(nft.MINTER_ROLE(), minter);
        nft.grantRole(nft.BURNER_ROLE(), burner);
        vm.stopPrank();
    }

    // ─── Deployment
    // ──────────────────────────────────────────────

    function test_AdminHasDefaultAdminRole() public view {
        assertTrue(nft.hasRole(nft.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_MinterHasMinterRole() public view {
        assertTrue(nft.hasRole(nft.MINTER_ROLE(), minter));
    }

    function test_BurnerHasBurnerRole() public view {
        assertTrue(nft.hasRole(nft.BURNER_ROLE(), burner));
    }

    function test_PolicyTypeConstants() public view {
        assertEq(nft.STABLECOIN_DEPEG(), 0);
        assertEq(nft.LIQUIDATION_PROTECTION(), 1);
        assertEq(nft.SMART_CONTRACT_HACK(), 2);
    }

    // ─── Minting
    // ─────────────────────────────────────────────────

    function test_MintPolicy_Success() public {
        // Arrange
        uint256 typeId = nft.STABLECOIN_DEPEG();
        uint256 amount = 5;

        // Act
        vm.prank(minter);
        nft.mintPolicy(alice, typeId, amount, "");

        // Assert
        assertEq(nft.balanceOf(alice, typeId), amount);
        assertEq(nft.totalSupply(typeId), amount);
    }

    function test_MintPolicy_MultipleTypes() public {
        // Act: mint different types to alice
        vm.startPrank(minter);
        nft.mintPolicy(alice, 0, 10, "");
        nft.mintPolicy(alice, 1, 20, "");
        nft.mintPolicy(alice, 2, 30, "");
        vm.stopPrank();

        // Assert
        assertEq(nft.balanceOf(alice, 0), 10);
        assertEq(nft.balanceOf(alice, 1), 20);
        assertEq(nft.balanceOf(alice, 2), 30);
    }

    function test_MintPolicy_RevertWithoutRole() public {
        // Arrange: cache role before prank
        bytes32 minterRole = nft.MINTER_ROLE();

        // Act & Assert: alice (no MINTER_ROLE) cannot mint
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, minterRole)
        );
        nft.mintPolicy(alice, 0, 1, "");
    }

    // ─── Burning
    // ─────────────────────────────────────────────────

    function test_BurnPolicy_Success() public {
        // Arrange: mint tokens first
        vm.prank(minter);
        nft.mintPolicy(alice, 0, 10, "");

        // Act
        vm.prank(burner);
        nft.burnPolicy(alice, 0, 3);

        // Assert
        assertEq(nft.balanceOf(alice, 0), 7);
        assertEq(nft.totalSupply(0), 7);
    }

    function test_BurnPolicy_RevertWithoutRole() public {
        // Arrange: mint tokens, cache role before prank
        vm.prank(minter);
        nft.mintPolicy(alice, 0, 5, "");
        bytes32 burnerRole = nft.BURNER_ROLE();

        // Act & Assert
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, burnerRole)
        );
        nft.burnPolicy(alice, 0, 1);
    }

    function test_BurnPolicy_RevertInsufficientBalance() public {
        // Arrange: mint 5 tokens
        vm.prank(minter);
        nft.mintPolicy(alice, 0, 5, "");

        // Act & Assert: try to burn 10
        vm.prank(burner);
        vm.expectRevert();
        nft.burnPolicy(alice, 0, 10);
    }

    // ─── URI
    // ─────────────────────────────────────────────────────

    function test_URI_ReturnsCorrectFormat() public view {
        assertEq(nft.uri(0), string.concat(BASE_URI, "0"));
        assertEq(nft.uri(1), string.concat(BASE_URI, "1"));
        assertEq(nft.uri(2), string.concat(BASE_URI, "2"));
        assertEq(nft.uri(42), string.concat(BASE_URI, "42"));
    }

    // ─── Supports Interface
    // ──────────────────────────────────────

    function test_SupportsInterface_ERC1155() public view {
        // ERC-1155 interface id
        assertTrue(nft.supportsInterface(0xd9b67a26));
    }

    function test_SupportsInterface_AccessControl() public view {
        // IAccessControl interface id
        assertTrue(nft.supportsInterface(type(IAccessControl).interfaceId));
    }

    function test_SupportsInterface_ERC165() public view {
        // ERC-165 interface id
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    // ─── Supply Tracking
    // ─────────────────────────────────────────

    function test_TotalSupply_TracksCorrectly() public {
        // Arrange & Act
        vm.startPrank(minter);
        nft.mintPolicy(alice, 0, 100, "");
        nft.mintPolicy(bob, 0, 50, "");
        vm.stopPrank();

        // Assert
        assertEq(nft.totalSupply(0), 150);
        assertTrue(nft.exists(0));
        assertFalse(nft.exists(1));
    }

    // ─── Batch Operations
    // ────────────────────────────────────────

    function test_SafeBatchTransferFrom_Success() public {
        // Arrange: mint multiple types
        vm.startPrank(minter);
        nft.mintPolicy(alice, 0, 10, "");
        nft.mintPolicy(alice, 1, 20, "");
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5;
        amounts[1] = 10;

        // Act
        vm.prank(alice);
        nft.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        // Assert
        assertEq(nft.balanceOf(alice, 0), 5);
        assertEq(nft.balanceOf(alice, 1), 10);
        assertEq(nft.balanceOf(bob, 0), 5);
        assertEq(nft.balanceOf(bob, 1), 10);
    }

    function test_BalanceOfBatch() public {
        // Arrange
        vm.startPrank(minter);
        nft.mintPolicy(alice, 0, 10, "");
        nft.mintPolicy(bob, 1, 20, "");
        vm.stopPrank();

        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        // Act
        uint256[] memory balances = nft.balanceOfBatch(accounts, ids);

        // Assert
        assertEq(balances[0], 10);
        assertEq(balances[1], 20);
    }

    // ─── Fuzz
    // ────────────────────────────────────────────────────

    function testFuzz_MintBurn_SupplyConsistent(uint256 mintAmount, uint256 burnAmount) public {
        // Arrange
        mintAmount = bound(mintAmount, 1, 1e18);
        burnAmount = bound(burnAmount, 0, mintAmount);

        // Act
        vm.prank(minter);
        nft.mintPolicy(alice, 0, mintAmount, "");
        vm.prank(burner);
        nft.burnPolicy(alice, 0, burnAmount);

        // Assert
        assertEq(nft.balanceOf(alice, 0), mintAmount - burnAmount);
        assertEq(nft.totalSupply(0), mintAmount - burnAmount);
    }
}
