// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../../src/ChainlinkOracleAdapter.sol";

/// @title MockAggregator
/// @notice Test double for Chainlink AggregatorV3Interface.
///         Allows manually setting price, updatedAt, and round metadata to
///         exercise every validation branch in ChainlinkOracleAdapter.
contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint80 private _answeredInRound;
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
        _roundId = 1;
        _answeredInRound = 1;
        _answer = 2000e8;
        _updatedAt = block.timestamp;
    }

    function setPrice(int256 price) external {
        _answer = price;
    }

    function setUpdatedAt(uint256 ts) external {
        _updatedAt = ts;
    }

    function setRoundData(uint80 roundId, uint80 answeredInRound) external {
        _roundId = roundId;
        _answeredInRound = answeredInRound;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _answeredInRound);
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }
}
