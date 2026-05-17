// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimpleERC20.sol";
import "./LPToken.sol";

/**
 * @title ConstantProductAMM
 * @notice A constant product Automated Market Maker (x * y = k)
 * @dev Implements Uniswap V2-style AMM with 0.3% swap fee
 */
contract ConstantProductAMM {
    SimpleERC20 public immutable tokenA;
    SimpleERC20 public immutable tokenB;
    LPToken public immutable lpToken;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public constant FEE_BPS = 30; // 0.3% = 30 basis points
    uint256 public constant BASIS_POINTS = 10000;

    bool public initialized;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    error ZeroAmount();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error SlippageTooHigh();
    error InvalidTokenAddress();
    error AlreadyInitialized();

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = SimpleERC20(_tokenA);
        tokenB = SimpleERC20(_tokenB);

        lpToken = new LPToken("AMM LP Token", "AMM-LP");
    }

    /**
     * @notice Add liquidity to the pool
     * @param amountA Amount of tokenA to deposit
     * @param amountB Amount of tokenB to deposit
     * @param minLiquidity Minimum LP tokens expected (slippage protection)
     * @return liquidity LP tokens minted
     */
    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLiquidity) external returns (uint256 liquidity) {
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        // Transfer tokens from user
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (!initialized) {
            // First liquidity provider
            liquidity = _sqrt(amountA * amountB);
            if (liquidity == 0) revert InsufficientLiquidity();
            initialized = true;
        } else {
            // Subsequent liquidity: calculate proportionally
            uint256 liquidityA = (amountA * lpToken.totalSupply()) / reserveA;
            uint256 liquidityB = (amountB * lpToken.totalSupply()) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        if (liquidity < minLiquidity) revert SlippageTooHigh();

        lpToken.mint(msg.sender, liquidity);
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @notice Remove liquidity from the pool
     * @param liquidity Amount of LP tokens to burn
     * @param minAmountA Minimum tokenA expected (slippage protection)
     * @param minAmountB Minimum tokenB expected (slippage protection)
     * @return amountA Amount of tokenA returned
     * @return amountB Amount of tokenB returned
     */
    function removeLiquidity(uint256 liquidity, uint256 minAmountA, uint256 minAmountB)
        external
        returns (uint256 amountA, uint256 amountB)
    {
        if (liquidity == 0) revert ZeroAmount();
        if (lpToken.balanceOf(msg.sender) < liquidity) revert InsufficientLiquidity();

        uint256 totalLiquidity = lpToken.totalSupply();
        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        if (amountA < minAmountA || amountB < minAmountB) revert SlippageTooHigh();

        lpToken.burn(msg.sender, liquidity);

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @notice Swap tokens using constant product formula
     * @param tokenIn Address of token to swap from
     * @param amountIn Amount of input tokens
     * @param minAmountOut Minimum output amount (slippage protection)
     * @return amountOut Amount of output tokens received
     */
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (tokenIn != address(tokenA) && tokenIn != address(tokenB)) revert InvalidTokenAddress();

        bool swappingAtoB = tokenIn == address(tokenA);
        SimpleERC20 inputToken = swappingAtoB ? tokenA : tokenB;
        SimpleERC20 outputToken = swappingAtoB ? tokenB : tokenA;

        inputToken.transferFrom(msg.sender, address(this), amountIn);

        amountOut = getAmountOut(tokenIn, amountIn);
        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut < minAmountOut) revert SlippageTooHigh();

        require(outputToken.transfer(msg.sender, amountOut), "Transfer out failed");

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Swap(msg.sender, tokenIn, swappingAtoB ? address(tokenB) : address(tokenA), amountIn, amountOut);
    }

    /**
     * @notice Calculate output amount for a given input
     * @param tokenIn Address of input token
     * @param amountIn Amount of input tokens
     * @return amountOut Amount of output tokens
     */
    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256 amountOut) {
        if (amountIn == 0) return 0;

        bool isTokenA = tokenIn == address(tokenA);
        uint256 reserveIn = isTokenA ? reserveA : reserveB;
        uint256 reserveOut = isTokenA ? reserveB : reserveA;

        if (reserveIn == 0 || reserveOut == 0) return 0;

        // Apply 0.3% fee
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - FEE_BPS);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * BASIS_POINTS) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    /**
     * @notice Get current reserves
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    /**
     * @notice Calculate square root (for initial liquidity)
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
