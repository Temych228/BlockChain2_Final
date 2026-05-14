// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// Minimal interfaces for mainnet contracts
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}

contract ForkTest is Test {
    // Mainnet contract addresses (Ethereum mainnet)
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    function setUp() public {
        // Skip fork tests if no RPC URL is configured
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return;
        }
        vm.createSelectFork(rpcUrl);
    }

    // Test 1: Read USDC total supply from mainnet
    function test_ReadUSDC_TotalSupply() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return;
        }

        uint256 totalSupply = IERC20(USDC).totalSupply();
        assertTrue(totalSupply > 0, "USDC total supply should be greater than 0");

        emit log_named_uint("USDC Total Supply (raw)", totalSupply);
        // USDC has 6 decimals
        emit log_named_uint("USDC Total Supply (human)", totalSupply / 1e6);
    }

    // Test 2: Simulate Uniswap V2 swap
    function test_SimulateUniswapV2Swap() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return;
        }

        // Deal some WETH to test address
        deal(WETH, address(this), 1 ether);

        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);

        // Approve router to spend WETH
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, 1 ether);

        // Build swap path: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        // Get expected output
        uint256[] memory amounts = router.getAmountsOut(0.1 ether, path);
        uint256 expectedOut = amounts[1];

        emit log_named_uint("WETH Input", 0.1 ether);
        emit log_named_uint("Expected USDC Output (raw)", expectedOut);
        emit log_named_uint("Expected USDC Output (human)", expectedOut / 1e6);

        // Perform the swap
        router.swapExactTokensForTokens(
            0.1 ether,
            expectedOut * 95 / 100, // 5% slippage tolerance
            path,
            address(this),
            block.timestamp + 60
        );

        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        assertTrue(usdcBalance > 0, "Should have received USDC");
        emit log_named_uint("USDC Received (raw)", usdcBalance);
    }

    // Test 3: Verify fork block number
    function test_ForkBlockNumber() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return;
        }

        uint256 blockNum = block.number;
        assertTrue(blockNum > 15_000_000, "Should be forked from a recent block");
        emit log_named_uint("Forked Block Number", blockNum);
    }
}
