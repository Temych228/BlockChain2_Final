// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IOracle} from "./interfaces/IOracle.sol";

/// @dev Minimal Chainlink AggregatorV3Interface (avoids external dependency).
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

/// @title ChainlinkOracleAdapter
/// @notice Production adapter wrapping a Chainlink AggregatorV3 price feed with full
///         safety checks: staleness, negative price, and incomplete round validation.
/// @dev Implements the project's IOracle interface so it can be plugged into
///      InsurancePool without changing any other contract.
contract ChainlinkOracleAdapter is IOracle, AccessControl {
    AggregatorV3Interface public immutable feed;

    /// @notice Maximum acceptable age (seconds) of a price update before it is
    ///         considered stale. Configurable by admin.
    uint256 public maxStaleness;

    event MaxStalenessUpdated(uint256 oldValue, uint256 newValue);

    error StalePrice(uint256 updatedAt, uint256 currentTime, uint256 maxAge);
    error NegativeOrZeroPrice(int256 answer);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);
    error ZeroAddress();
    error ZeroStaleness();

    /// @param _feed        Address of the Chainlink AggregatorV3 price feed.
    /// @param _maxStaleness Initial staleness threshold in seconds (e.g. 3600 for 1 h).
    /// @param _admin       Address receiving DEFAULT_ADMIN_ROLE.
    constructor(address _feed, uint256 _maxStaleness, address _admin) {
        if (_feed == address(0) || _admin == address(0)) revert ZeroAddress();
        if (_maxStaleness == 0) revert ZeroStaleness();

        feed = AggregatorV3Interface(_feed);
        maxStaleness = _maxStaleness;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @inheritdoc IOracle
    function getPrice() external view override returns (uint256 price, uint256 updatedAt) {
        (uint80 roundId, int256 answer,, uint256 updatedAt_, uint80 answeredInRound) = feed.latestRoundData();

        if (answer <= 0) revert NegativeOrZeroPrice(answer);
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);
        if (block.timestamp - updatedAt_ > maxStaleness) {
            revert StalePrice(updatedAt_, block.timestamp, maxStaleness);
        }

        price = uint256(answer);
        updatedAt = updatedAt_;
    }

    /// @notice Updates the staleness threshold.
    /// @param _maxStaleness New threshold in seconds.
    function setMaxStaleness(uint256 _maxStaleness) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_maxStaleness == 0) revert ZeroStaleness();
        emit MaxStalenessUpdated(maxStaleness, _maxStaleness);
        maxStaleness = _maxStaleness;
    }
}
