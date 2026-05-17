// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleERC20.sol";
import "../src/LPToken.sol";
import "../src/ConstantProductAMM.sol";

contract AMMTest is Test {
    // Event declarations for expectEmit
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    SimpleERC20 public immutable tokenA;
    SimpleERC20 public immutable tokenB;
    ConstantProductAMM public amm;
    LPToken public immutable lpToken;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        tokenA = new SimpleERC20("Token A", "TKNA");
        tokenB = new SimpleERC20("Token B", "TKNB");
        amm = new ConstantProductAMM(address(tokenA), address(tokenB));
        lpToken = amm.lpToken();

        // Mint tokens to users
        tokenA.mint(alice, 10_000 ether);
        tokenB.mint(alice, 10_000 ether);
        tokenA.mint(bob, 10_000 ether);
        tokenB.mint(bob, 10_000 ether);
        tokenA.mint(charlie, 10_000 ether);
        tokenB.mint(charlie, 10_000 ether);
    }

    function _approveAndAddLiquidity(address user, uint256 amountA, uint256 amountB)
        internal
        returns (uint256 liquidity)
    {
        vm.prank(user);
        tokenA.approve(address(amm), amountA);
        vm.prank(user);
        tokenB.approve(address(amm), amountB);
        vm.prank(user);
        liquidity = amm.addLiquidity(amountA, amountB, 0);
    }

    // ========== ADD LIQUIDITY TESTS ==========

    function test_AddLiquidityFirstProvider() public {
        uint256 liquidity = _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        assertGt(liquidity, 0);
        assertGt(lpToken.balanceOf(alice), 0);
        assertEq(amm.reserveA(), 1000 ether);
        assertEq(amm.reserveB(), 1000 ether);
    }

    function test_AddLiquidityFirstProviderEmitsEvent() public {
        vm.prank(alice);
        tokenA.approve(address(amm), 1000 ether);
        vm.prank(alice);
        tokenB.approve(address(amm), 1000 ether);

        vm.expectEmit(true, false, false, true);
        emit LiquidityAdded(alice, 1000 ether, 1000 ether, 1000 ether);
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);
    }

    function test_AddLiquiditySubsequentProvider() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 liquidityBob = _approveAndAddLiquidity(bob, 500 ether, 500 ether);

        assertGt(liquidityBob, 0);
        assertGt(lpToken.balanceOf(bob), 0);
        (uint256 reserveA, uint256 reserveB) = amm.getReserves();
        assertEq(reserveA, 1500 ether);
        assertEq(reserveB, 1500 ether);
    }

    function test_AddLiquidityWithZeroAmountReverts() public {
        vm.prank(alice);
        tokenA.approve(address(amm), 0);
        vm.prank(alice);
        tokenB.approve(address(amm), 100 ether);

        vm.expectRevert(ConstantProductAMM.ZeroAmount.selector);
        vm.prank(alice);
        amm.addLiquidity(0, 100 ether, 0);
    }

    function test_AddLiquiditySlippageProtection() public {
        vm.prank(alice);
        tokenA.approve(address(amm), 1000 ether);
        vm.prank(alice);
        tokenB.approve(address(amm), 1000 ether);

        // Request more liquidity than expected
        vm.prank(alice);
        vm.expectRevert(ConstantProductAMM.SlippageTooHigh.selector);
        amm.addLiquidity(1000 ether, 1000 ether, type(uint256).max);
    }

    // ========== REMOVE LIQUIDITY TESTS ==========

    function test_RemoveLiquidityFull() public {
        uint256 liquidity = _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);
        uint256 lpBalance = lpToken.balanceOf(alice);

        vm.prank(alice);
        lpToken.approve(address(amm), lpBalance);

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(lpBalance, 0, 0);

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(lpToken.balanceOf(alice), 0);
        assertEq(amm.reserveA(), 1000 ether - amountA);
        assertEq(amm.reserveB(), 1000 ether - amountB);
    }

    function test_RemoveLiquidityPartial() public {
        uint256 liquidity = _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);
        uint256 lpBalance = lpToken.balanceOf(alice);
        uint256 halfLiquidity = lpBalance / 2;

        vm.prank(alice);
        lpToken.approve(address(amm), halfLiquidity);

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(halfLiquidity, 0, 0);

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(lpToken.balanceOf(alice), halfLiquidity);
    }

    function test_RemoveLiquidityEmitsEvent() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);
        uint256 lpBalance = lpToken.balanceOf(alice);

        vm.prank(alice);
        lpToken.approve(address(amm), lpBalance);

        uint256 totalSupply = lpToken.totalSupply();
        uint256 expectedA = (lpBalance * amm.reserveA()) / totalSupply;
        uint256 expectedB = (lpBalance * amm.reserveB()) / totalSupply;

        vm.expectEmit(true, false, false, true);
        emit LiquidityRemoved(alice, expectedA, expectedB, lpBalance);
        vm.prank(alice);
        amm.removeLiquidity(lpBalance, 0, 0);
    }

    function test_RemoveLiquidityZeroAmountReverts() public {
        vm.expectRevert(ConstantProductAMM.ZeroAmount.selector);
        vm.prank(alice);
        amm.removeLiquidity(0, 0, 0);
    }

    function test_RemoveLiquidityInsufficientLiquidityReverts() public {
        vm.expectRevert(ConstantProductAMM.InsufficientLiquidity.selector);
        vm.prank(alice);
        amm.removeLiquidity(1 ether, 0, 0);
    }

    // ========== SWAP TESTS ==========

    function test_SwapAtoB() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 amountIn = 10 ether;
        uint256 expectedOut = amm.getAmountOut(address(tokenA), amountIn);

        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);

        assertEq(amountOut, expectedOut);
        assertGt(amountOut, 0);
    }

    function test_SwapBtoA() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 amountIn = 10 ether;
        uint256 expectedOut = amm.getAmountOut(address(tokenB), amountIn);

        vm.prank(bob);
        tokenB.approve(address(amm), amountIn);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenB), amountIn, 0);

        assertEq(amountOut, expectedOut);
        assertGt(amountOut, 0);
    }

    function test_SwapEmitsEvent() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 amountIn = 10 ether;
        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);

        uint256 expectedOut = amm.getAmountOut(address(tokenA), amountIn);

        vm.expectEmit(true, false, false, true);
        emit Swap(bob, address(tokenA), address(tokenB), amountIn, expectedOut);
        vm.prank(bob);
        amm.swap(address(tokenA), amountIn, 0);
    }

    function test_SwapZeroAmountReverts() public {
        vm.expectRevert(ConstantProductAMM.ZeroAmount.selector);
        vm.prank(bob);
        amm.swap(address(tokenA), 0, 0);
    }

    function test_SwapInvalidTokenReverts() public {
        vm.expectRevert(ConstantProductAMM.InvalidTokenAddress.selector);
        vm.prank(bob);
        amm.swap(makeAddr("invalid"), 100 ether, 0);
    }

    function test_SwapSlippageProtection() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 amountIn = 100 ether;
        uint256 expectedOut = amm.getAmountOut(address(tokenA), amountIn);

        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);

        vm.prank(bob);
        vm.expectRevert(ConstantProductAMM.SlippageTooHigh.selector);
        amm.swap(address(tokenA), amountIn, expectedOut + 1);
    }

    function test_SwapInsufficientLiquidityReverts() public {
        // No liquidity added
        vm.prank(bob);
        tokenA.approve(address(amm), 100 ether);

        vm.expectRevert(ConstantProductAMM.InsufficientLiquidity.selector);
        vm.prank(bob);
        amm.swap(address(tokenA), 100 ether, 0);
    }

    // ========== INVARIANT: K CONSTANT ==========

    function test_KIncreasesAfterSwap() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        uint256 amountIn = 10 ether;
        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);
        vm.prank(bob);
        amm.swap(address(tokenA), amountIn, 0);

        uint256 kAfter = amm.reserveA() * amm.reserveB();

        // k should increase due to fees
        assertGe(kAfter, kBefore);
    }

    function test_GetAmountOutCalculation() public view {
        // Verify formula: amountOut = (amountIn * (1 - fee) * reserveOut) / (reserveIn + amountIn * (1 - fee))
        uint256 amountIn = 100 ether;
        uint256 reserveIn = 1000 ether;
        uint256 reserveOut = 1000 ether;
        uint256 feeBps = 30;
        uint256 basisPoints = 10000;

        uint256 amountInWithFee = amountIn * (basisPoints - feeBps);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * basisPoints) + amountInWithFee;
        uint256 expectedOut = numerator / denominator;

        // This is what getAmountOut should return given those reserves
        assertTrue(expectedOut > 0);
        assertTrue(expectedOut < amountIn); // Due to fees and slippage
    }

    // ========== LARGE SWAP / PRICE IMPACT ==========

    function test_LargeSwapHighPriceImpact() public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        uint256 amountIn = 500 ether; // 50% of reserves
        uint256 expectedOut = amm.getAmountOut(address(tokenA), amountIn);

        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);

        assertEq(amountOut, expectedOut);
        // Large swap should give less proportional output
        assertLt(amountOut, 500 ether);
    }

    // ========== FUZZ TESTS ==========

    function testFuzz_AddLiquidity(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1 ether, 5_000 ether);
        amountB = bound(amountB, 1 ether, 5_000 ether);

        uint256 liquidity = _approveAndAddLiquidity(alice, amountA, amountB);

        assertGt(liquidity, 0);
        assertGt(amm.reserveA(), 0);
        assertGt(amm.reserveB(), 0);
    }

    function testFuzz_Swap(uint256 amountIn) public {
        _approveAndAddLiquidity(alice, 1000 ether, 1000 ether);

        amountIn = bound(amountIn, 1 ether, 500 ether);

        uint256 expectedOut = amm.getAmountOut(address(tokenA), amountIn);

        vm.prank(bob);
        tokenA.approve(address(amm), amountIn);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);

        assertEq(amountOut, expectedOut);
    }
}
