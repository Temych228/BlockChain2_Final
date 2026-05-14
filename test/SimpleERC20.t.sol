// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleERC20.sol";

contract SimpleERC20Test is Test {
    // Event declarations for expectEmit
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    SimpleERC20 public token;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        token = new SimpleERC20("Test Token", "TST");
    }

    // ========== UNIT TESTS ==========

    function test_InitialState() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function test_Mint() public {
        token.mint(alice, 1000 ether);
        assertEq(token.totalSupply(), 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function test_MintEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), alice, 1000 ether);
        token.mint(alice, 1000 ether);
    }

    function test_MintToZeroAddressReverts() public {
        vm.expectRevert("ERC20: mint to zero address");
        token.mint(address(0), 1000 ether);
    }

    function test_Transfer() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        bool success = token.transfer(bob, 500 ether);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.balanceOf(bob), 500 ether);
    }

    function test_TransferEmitsEvent() public {
        token.mint(alice, 1000 ether);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 500 ether);
        vm.prank(alice);
        token.transfer(bob, 500 ether);
    }

    function test_TransferInsufficientBalanceReverts() public {
        token.mint(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient balance");
        token.transfer(bob, 200 ether);
    }

    function test_TransferToZeroAddressReverts() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        vm.expectRevert("ERC20: transfer to zero address");
        token.transfer(address(0), 100 ether);
    }

    function test_Approve() public {
        vm.prank(alice);
        bool success = token.approve(bob, 500 ether);
        assertTrue(success);
        assertEq(token.allowance(alice, bob), 500 ether);
    }

    function test_ApproveEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 500 ether);
        vm.prank(alice);
        token.approve(bob, 500 ether);
    }

    function test_TransferFrom() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 500 ether);

        vm.prank(bob);
        bool success = token.transferFrom(alice, charlie, 300 ether);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 700 ether);
        assertEq(token.balanceOf(charlie), 300 ether);
        assertEq(token.allowance(alice, bob), 200 ether);
    }

    function test_TransferFromEmitsEvent() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 500 ether);

        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, charlie, 300 ether);
        vm.prank(bob);
        token.transferFrom(alice, charlie, 300 ether);
    }

    function test_TransferFromInsufficientAllowanceReverts() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 100 ether);

        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        token.transferFrom(alice, charlie, 200 ether);
    }

    function test_TransferFromInsufficientBalanceReverts() public {
        token.mint(alice, 100 ether);
        vm.prank(alice);
        token.approve(bob, 200 ether);

        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient balance");
        token.transferFrom(alice, charlie, 200 ether);
    }

    function test_TransferFromToZeroAddressReverts() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(bob, 500 ether);

        vm.prank(bob);
        vm.expectRevert("ERC20: transferFrom to zero address");
        token.transferFrom(alice, address(0), 100 ether);
    }

    function test_TransferFullBalance() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.transfer(bob, 1000 ether);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1000 ether);
    }

    function test_MultipleMints() public {
        token.mint(alice, 100 ether);
        token.mint(bob, 200 ether);
        token.mint(charlie, 300 ether);
        assertEq(token.totalSupply(), 600 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.balanceOf(charlie), 300 ether);
    }

    // ========== FUZZ TESTS ==========

    function testFuzz_Trans(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1, 1_000_000 ether);
        token.mint(alice, amount);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
    }

    function testFuzz_TransferPartial(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, 1_000_000 ether);
        transferAmount = bound(transferAmount, 1, mintAmount);

        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function testFuzz_ApproveAndTransferFrom(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);
        token.mint(alice, amount);

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.allowance(alice, bob), 0);
    }

    // ========== INVARIANT TESTS ==========

    function testInvariant_TotalSupplyUnchangedAfterTransfer() public {
        token.mint(alice, 1000 ether);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(alice);
        token.transfer(bob, 500 ether);

        assertEq(token.totalSupply(), totalSupplyBefore);
    }

    function testInvariant_NoAddressExceedsTotalSupply() public {
        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);
        uint256 totalSupply = token.totalSupply();

        assertLe(token.balanceOf(alice), totalSupply);
        assertLe(token.balanceOf(bob), totalSupply);
        assertLe(token.balanceOf(charlie), totalSupply);
    }

    function testInvariant_SumOfBalancesEqualsTotalSupply() public {
        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);
        token.mint(charlie, 250 ether);
        uint256 totalSupply = token.totalSupply();

        uint256 sumBalances = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(charlie);
        assertEq(sumBalances, totalSupply);
    }
}
