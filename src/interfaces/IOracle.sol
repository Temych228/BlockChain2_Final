// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOracle
/// @notice Generic oracle interface for price feed adapters.
interface IOracle {
    /// @notice Returns the latest price for the tracked asset.
    /// @return price The asset price (scaled per feed, e.g. 8 decimals for Chainlink).
    /// @return updatedAt The timestamp of the last price update.
    function getPrice() external view returns (uint256 price, uint256 updatedAt);
}
