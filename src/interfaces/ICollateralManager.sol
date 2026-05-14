// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICollateralManager
/// @notice Interface for the lending-pool-style collateral management contract.
interface ICollateralManager {
    /// @notice Deposits USDC collateral for the caller.
    /// @param amount The USDC amount to deposit.
    function depositCollateral(uint256 amount) external;

    /// @notice Withdraws USDC collateral, subject to health factor checks.
    /// @param amount The USDC amount to withdraw.
    function withdrawCollateral(uint256 amount) external;

    /// @notice Returns the health factor for an underwriter.
    /// @param underwriter The underwriter address.
    /// @return The health factor in basis points (type(uint256).max if no exposure).
    function healthFactor(address underwriter) external view returns (uint256);

    /// @notice Checks if an underwriter position is liquidatable.
    /// @param underwriter The underwriter address.
    /// @return True if the position can be liquidated.
    function isLiquidatable(address underwriter) external view returns (bool);

    /// @notice Liquidates an undercollateralized underwriter position.
    /// @param underwriter The underwriter to liquidate.
    /// @param liquidator The address receiving the seized collateral.
    function liquidate(address underwriter, address liquidator) external;

    /// @notice Returns the current pool utilization rate.
    /// @return The utilization ratio scaled to 1e18.
    function utilizationRate() external view returns (uint256);

    /// @notice Increases an underwriter's coverage exposure. Only callable by InsurancePool.
    /// @param underwriter The underwriter address.
    /// @param coverageAmount The coverage amount to add.
    function increaseExposure(address underwriter, uint256 coverageAmount) external;

    /// @notice Decreases an underwriter's coverage exposure. Only callable by InsurancePool.
    /// @param underwriter The underwriter address.
    /// @param coverageAmount The coverage amount to remove.
    function decreaseExposure(address underwriter, uint256 coverageAmount) external;
}
