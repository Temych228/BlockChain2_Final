// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleERC20.sol";
import "../src/LendingPool.sol";

contract LendingPoolTest is Test {
    // Event declarations for expectEmit
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 repayAmount, uint256 collateralSeized);

    SimpleERC20 public collateralToken;
    SimpleERC20 public borrowToken;
    LendingPool public pool;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        collateralToken = new SimpleERC20("Collateral Token", "COLL");
        borrowToken = new SimpleERC20("Borrow Token", "BORR");
        pool = new LendingPool(address(collateralToken), address(borrowToken));

        // Mint tokens
        borrowToken.mint(address(pool), 100_000 ether);
        collateralToken.mint(alice, 10_000 ether);
        borrowToken.mint(alice, 10_000 ether);
        collateralToken.mint(bob, 10_000 ether);
        borrowToken.mint(bob, 10_000 ether);
        collateralToken.mint(charlie, 10_000 ether);
        borrowToken.mint(charlie, 10_000 ether);
    }

    function _deposit(address user, uint256 amount) internal {
        vm.prank(user);
        collateralToken.approve(address(pool), amount);
        vm.prank(user);
        pool.deposit(amount);
    }

    function _borrow(address user, uint256 amount) internal {
        vm.prank(user);
        pool.borrow(amount);
    }

    function _repay(address user, uint256 amount) internal {
        vm.prank(user);
        borrowToken.approve(address(pool), amount);
        vm.prank(user);
        pool.repay(amount);
    }

    // ========== DEPOSIT TESTS ==========

    function test_Deposit() public {
        _deposit(alice, 1000 ether);

        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 1000 ether);
        assertEq(pool.totalDeposited(), 1000 ether);
        assertEq(collateralToken.balanceOf(address(pool)), 1000 ether);
    }

    function test_DepositEmitsEvent() public {
        vm.prank(alice);
        collateralToken.approve(address(pool), 1000 ether);

        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1000 ether);
        vm.prank(alice);
        pool.deposit(1000 ether);
    }

    function test_DepositZeroReverts() public {
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.deposit(0);
    }

    // ========== WITHDRAW TESTS ==========

    function test_Withdraw() public {
        _deposit(alice, 1000 ether);

        vm.prank(alice);
        pool.withdraw(500 ether);

        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 500 ether);
        assertEq(pool.totalDeposited(), 500 ether);
        assertEq(collateralToken.balanceOf(alice), 9_500 ether);
    }

    function test_WithdrawFull() public {
        _deposit(alice, 1000 ether);

        vm.prank(alice);
        pool.withdraw(1000 ether);

        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 0);
    }

    function test_WithdrawWithDebtReverts() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);

        vm.prank(alice);
        vm.expectRevert(LendingPool.HealthFactorBelowOne.selector);
        pool.withdraw(500 ether);
    }

    function test_WithdrawInsufficientDepositedReverts() public {
        _deposit(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientDeposited.selector);
        pool.withdraw(200 ether);
    }

    function test_WithdrawZeroReverts() public {
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.withdraw(0);
    }

    // ========== BORROW TESTS ==========

    function test_BorrowWithinLTV() public {
        _deposit(alice, 1000 ether);
        
        // Max borrow = 1000 * 0.75 = 750
        _borrow(alice, 500 ether);

        (, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 500 ether);
        assertEq(borrowToken.balanceOf(alice), 10_500 ether);

    }

    function test_BorrowExceedsLTVReverts() public {
        _deposit(alice, 1000 ether);

        // Max borrow = 1000 * 0.75 = 750
        vm.expectRevert(LendingPool.ExceedsLTV.selector);
        _borrow(alice, 800 ether);
    }

    function test_BorrowZeroCollateralReverts() public {
        vm.expectRevert(LendingPool.InsufficientCollateral.selector);
        _borrow(alice, 100 ether);
    }

    function test_BorrowEmitsEvent() public {
        _deposit(alice, 1000 ether);

        vm.expectEmit(true, false, false, true);
        emit Borrow(alice, 500 ether);
        vm.prank(alice);
        pool.borrow(500 ether);
    }

    // ========== REPAY TESTS ==========

    function test_RepayFull() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);
        _repay(alice, 500 ether);

        (, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 0);
        assertEq(pool.totalBorrowed(), 0);
    }

    function test_RepayPartial() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);
        _repay(alice, 200 ether);

        (, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 300 ether);
        assertEq(pool.totalBorrowed(), 300 ether);
    }

    function test_RepayEmitsEvent() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);

        vm.prank(alice);
        borrowToken.approve(address(pool), 500 ether);

        vm.expectEmit(true, false, false, true);
        emit Repay(alice, 500 ether);
        vm.prank(alice);
        pool.repay(500 ether);
    }

    function test_RepayZeroReverts() public {
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.repay(0);
    }

    // ========== LIQUIDATION TESTS ==========

    function test_LiquidateUndercollateralized() public {
    _deposit(alice, 1000 ether);
    _borrow(alice, 749 ether);

    vm.warp(block.timestamp + 31536000 * 43 / 10);

    (, , uint256 healthFactor) = pool.getPosition(alice);
    assertLt(healthFactor, 1e18, "HF should be below 1");

    uint256 liquidatorBalanceBefore = collateralToken.balanceOf(charlie);

    vm.prank(charlie);
    borrowToken.approve(address(pool), type(uint256).max);

    borrowToken.mint(charlie, 10_000 ether);

    vm.prank(charlie);
    pool.liquidate(alice);

    assertGt(collateralToken.balanceOf(charlie), liquidatorBalanceBefore);
    (, uint256 newBorrowed,) = pool.getPosition(alice);
    assertEq(newBorrowed, 0);
}

    function test_LiquidateHealthyPositionReverts() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 100 ether);

        vm.prank(charlie);
        borrowToken.approve(address(pool), type(uint256).max);

        vm.expectRevert(LendingPool.HealthFactorAboveOne.selector);
        vm.prank(charlie);
        pool.liquidate(alice);
    }

    // ========== INTEREST ACCRUAL TESTS ==========

    function test_InterestAccrualOverTime() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);

        (, uint256 borrowedBefore,) = pool.getPosition(alice);
        assertEq(borrowedBefore, 500 ether);

        // Warp 1 year forward
        vm.warp(block.timestamp + 31536000);

        (, uint256 borrowedAfter,) = pool.getPosition(alice);
        // 5% interest on 500 = 25
        assertGt(borrowedAfter, 500 ether);
        assertEq(borrowedAfter, 525 ether);
    }

    function test_InterestAccrualSixMonths() public {
        _deposit(alice, 1000 ether);
        _borrow(alice, 700 ether);

        // Warp 6 months forward
        vm.warp(block.timestamp + 15768000);

        (, uint256 borrowedAfter,) = pool.getPosition(alice);
        uint256 expectedInterest = (700 ether * 500 * 15768000) / (10000 * 31536000);        assertEq(borrowedAfter, 700 ether + expectedInterest);
    }

    // ========== EDGE CASES ==========

    function test_FullFlow() public {
        // Deposit -> Borrow -> Repay -> Withdraw
        _deposit(alice, 1000 ether);
        _borrow(alice, 500 ether);
        _repay(alice, 500 ether);
        
        vm.prank(alice);
        pool.withdraw(1000 ether);

        (uint256 deposited, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(deposited, 0);
        assertEq(borrowed, 0);
    }

    function test_MultipleUsers() public {
        _deposit(alice, 1000 ether);
        _deposit(bob, 2000 ether);

        _borrow(alice, 500 ether);
        _borrow(bob, 1000 ether);

        assertEq(pool.totalDeposited(), 3000 ether);
        assertEq(pool.totalBorrowed(), 1500 ether);

        (uint256 aliceDeposited,,) = pool.getPosition(alice);
        (uint256 bobDeposited,,) = pool.getPosition(bob);
        assertEq(aliceDeposited, 1000 ether);
        assertEq(bobDeposited, 2000 ether);
    }
}
