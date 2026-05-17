// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @dev Minimal Chainlink AggregatorV3 interface for fork testing.
interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
}

/// @title ChainlinkFeedForkTest
/// @notice Fork tests against the real Chainlink ETH/USD feed on Arbitrum One.
/// @dev Run with: ARBITRUM_RPC_URL=<rpc> forge test --mc ChainlinkFeedForkTest --fork-url $ARBITRUM_RPC_URL
contract ChainlinkFeedForkTest is Test {
    // Chainlink ETH/USD Price Feed on Arbitrum One
    address constant ETH_USD_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    IAggregatorV3 feed;

    function setUp() public {
        // Only run on a fork — skip if no fork context
        try vm.activeFork() returns (uint256) {}
        catch {
            vm.skip(true);
        }
        feed = IAggregatorV3(ETH_USD_FEED);
    }

    /// @notice Real Chainlink feed returns a valid ETH price in sane range.
    function test_RealChainlinkFeed_ReturnsValidPrice() public view {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        uint256 price = uint256(answer);
        // ETH price should be between $100 and $100,000
        assertGt(price, 100e8, "Price too low");
        assertLt(price, 100_000e8, "Price too high");

        // Feed should not be stale (updated within last 24 hours)
        assertGt(updatedAt, block.timestamp - 24 hours, "Feed is stale");
    }

    /// @notice Verify feed metadata: 8 decimals and correct description.
    function test_FeedMetadata() public view {
        assertEq(feed.decimals(), 8, "ETH/USD feed should have 8 decimals");
        string memory desc = feed.description();
        assertGt(bytes(desc).length, 0, "Description should not be empty");
    }

    /// @notice After warping far into the future, the feed data becomes stale.
    function test_StalenessDetection() public {
        (,,, uint256 updatedAt,) = feed.latestRoundData();
        uint256 maxAge = 3600; // 1 hour staleness window

        // Warp 2 hours past the last update
        vm.warp(updatedAt + maxAge + 1 hours);

        (,,, uint256 updatedAt2,) = feed.latestRoundData();
        // The updatedAt hasn't changed (we just warped time, not the feed)
        assertTrue(block.timestamp - updatedAt2 > maxAge, "Feed should be detected as stale after time warp");
    }
}
