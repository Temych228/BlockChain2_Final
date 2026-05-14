// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InsurancePool} from "./InsurancePool.sol";
import {PremiumMath} from "./libraries/PremiumMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title InsurancePool V2
/// @notice Upgraded version of InsurancePool demonstrating the V1 → V2 UUPS upgrade path.
///         Adds a `policyCount` field tracking total policies ever created.
/// @dev Storage layout proof (no collision):
///
///      === V1 Layout ===
///      Slots 0–49:   OZ upgradeable base contracts
///      Slot  50:     vault
///      Slot  51:     collateralManager
///      Slot  52:     policyNFT
///      Slot  53:     oracle
///      Slot  54:     usdc
///      Slot  55:     totalPremiumsCollected
///      Slot  56:     policyTypes (mapping)
///      Slot  57:     policies (mapping)
///      Slot  58:     nextPolicyId
///      Slots 59–101: __gap[43]
///
///      === V2 Layout ===
///      Slots 0–58:   Same as V1 (unchanged)
///      Slots 59–100: __gap reduced to [42] (one slot freed)
///      Slot  101:    policyCount (NEW — occupies the slot released from __gap)
///
///      Total: 43 - 1 = 42 gap slots remain. No collision.
contract InsurancePoolV2 is InsurancePool {
    using SafeERC20 for IERC20;

    /// @notice Total number of policies ever created (cumulative counter).
    /// @dev This field is placed after the __gap, consuming one slot from the original gap.
    ///      The parent __gap[43] is effectively reduced to __gap[42] + policyCount.
    uint256 public policyCount;

    /// @notice Re-initializer for V2. Migrates existing data by syncing policyCount with nextPolicyId.
    /// @dev Uses reinitializer(2) so it can only be called once after the V1→V2 upgrade.
    function initializeV2() external reinitializer(2) {
        policyCount = nextPolicyId;
    }

    /// @inheritdoc InsurancePool
    /// @dev Overrides purchasePolicy to also increment the cumulative policyCount.
    function purchasePolicy(uint256 policyTypeId, uint256 coverageAmount, uint256 duration)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 policyId)
    {
        // Reuse V1 logic via internal call — replicate here to keep override clean
        // since super.purchasePolicy is external and cannot be called via super in override
        policyId = _purchasePolicyInternal(policyTypeId, coverageAmount, duration);
        policyCount++;
    }

    /// @notice Returns the protocol version string.
    /// @return "V2"
    function getVersion() external pure override returns (string memory) {
        return "V2";
    }

    /// @dev Internal implementation of purchasePolicy to share logic between V1 and V2.
    function _purchasePolicyInternal(uint256 policyTypeId, uint256 coverageAmount, uint256 duration)
        internal
        returns (uint256 policyId)
    {
        PolicyType storage pt = policyTypes[policyTypeId];
        if (!pt.active) revert PolicyTypeInactive();
        if (coverageAmount > pt.maxCoverage) revert CoverageExceedsMax(coverageAmount, pt.maxCoverage);
        if (duration > 365 days) revert DurationTooLong(duration, 365 days);

        uint256 utilization = collateralManager.utilizationRate();
        uint256 premium = PremiumMath.calculatePremium(coverageAmount, utilization, pt.riskMultiplier);

        policyId = nextPolicyId++;
        policies[policyId] = Policy({
            holder: msg.sender,
            policyTypeId: policyTypeId,
            coverageAmount: coverageAmount,
            premiumPaid: premium,
            expiry: block.timestamp + duration,
            state: PolicyState.ACTIVE
        });
        totalPremiumsCollected += premium;

        if (premium > 0) {
            usdc.safeTransferFrom(msg.sender, address(this), premium);
            usdc.forceApprove(address(vault), premium);
            vault.depositPremiums(premium);
        }
        collateralManager.increaseExposure(address(this), coverageAmount);
        policyNFT.mintPolicy(msg.sender, policyTypeId, 1, "");

        emit PolicyPurchased(policyId, msg.sender, policyTypeId, coverageAmount, premium);
    }
}
