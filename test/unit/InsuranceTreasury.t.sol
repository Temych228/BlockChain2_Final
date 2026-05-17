// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InsuranceTreasury} from "../../src/governance/InsuranceTreasury.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title InsuranceTreasury Unit Tests
/// @notice Covers ERC20 withdrawals, ETH withdrawals, receive, and access control.
contract InsuranceTreasuryTest is Test {
    InsuranceTreasury public treasury;
    MockERC20 public usdc;

    address admin = makeAddr("admin");
    address recipient = makeAddr("recipient");
    address nobody = makeAddr("nobody");

    function setUp() public {
        treasury = new InsuranceTreasury(admin);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdc.mint(address(treasury), 1_000_000e6);
    }

    function test_Constructor_ZeroAddress_Reverts() public {
        vm.expectRevert(InsuranceTreasury.ZeroAddress.selector);
        new InsuranceTreasury(address(0));
    }

    function test_WithdrawERC20_Success() public {
        vm.prank(admin);
        treasury.withdrawERC20(address(usdc), recipient, 10_000e6);

        assertEq(usdc.balanceOf(recipient), 10_000e6);
        assertEq(usdc.balanceOf(address(treasury)), 990_000e6);
    }

    function test_WithdrawERC20_ZeroAddress_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(InsuranceTreasury.ZeroAddress.selector);
        treasury.withdrawERC20(address(usdc), address(0), 100e6);
    }

    function test_WithdrawERC20_Unauthorized_Reverts() public {
        bytes32 role = treasury.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, role));
        treasury.withdrawERC20(address(usdc), recipient, 100e6);
    }

    function test_ReceiveETH() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(treasury).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(treasury).balance, 1 ether);
    }

    function test_WithdrawETH_Success() public {
        vm.deal(address(treasury), 5 ether);

        uint256 recipientBefore = recipient.balance;
        vm.prank(admin);
        treasury.withdrawETH(payable(recipient), 2 ether);

        assertEq(recipient.balance - recipientBefore, 2 ether);
        assertEq(address(treasury).balance, 3 ether);
    }

    function test_WithdrawETH_ZeroAddress_Reverts() public {
        vm.deal(address(treasury), 1 ether);
        vm.prank(admin);
        vm.expectRevert(InsuranceTreasury.ZeroAddress.selector);
        treasury.withdrawETH(payable(address(0)), 1 ether);
    }

    function test_WithdrawETH_Unauthorized_Reverts() public {
        vm.deal(address(treasury), 1 ether);
        bytes32 role = treasury.DEFAULT_ADMIN_ROLE();
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, role));
        treasury.withdrawETH(payable(recipient), 1 ether);
    }

    function test_WithdrawETH_FailedTransfer_Reverts() public {
        vm.deal(address(treasury), 1 ether);
        // Deploy a contract that rejects ETH
        RejectETH rejector = new RejectETH();
        vm.prank(admin);
        vm.expectRevert(InsuranceTreasury.ETHTransferFailed.selector);
        treasury.withdrawETH(payable(address(rejector)), 1 ether);
    }
}

/// @dev Helper contract that rejects incoming ETH to test the ETHTransferFailed path.
contract RejectETH {
    receive() external payable {
        revert("no eth");
    }
}
