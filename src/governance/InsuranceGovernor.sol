// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @title InsuranceGovernor
/// @notice Full OpenZeppelin Governor stack for the InsureDAO insurance protocol.
/// @dev Governance parameters (rubric §3.1):
///
///      Voting delay:  1 day (86400s)  — Time between proposal creation and voting start.
///                     Gives token holders time to acquire/delegate tokens before the
///                     snapshot is taken. Prevents surprise proposals.
///
///      Voting period: 1 week (604800s) — Active voting window duration.
///                     Balances governance responsiveness with sufficient participation
///                     time across different time zones.
///
///      Proposal threshold: 100,000 IDAO (1% of 10M initial supply) — Minimum tokens
///                          needed to create a proposal. Prevents spam while keeping
///                          governance accessible to significant stakeholders.
///
///      Quorum: 4% of total supply — Minimum voter participation for a proposal to pass.
///              Ensures meaningful community engagement on every decision.
///
///      Timelock: 2-day delay — Enforced by the TimelockController. Gives users time to
///               react (e.g., withdraw funds) before an approved proposal executes.
///
///      Clock:   EIP-6372 timestamp mode — Uses block.timestamp instead of block.number.
///               Required for L2 (Arbitrum) where block times are variable (~0.25s),
///               making block-based timing unreliable.
contract InsuranceGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @notice Deploys the governor bound to a governance token and timelock.
    /// @param _token The ERC20Votes governance token (GovernanceToken / IDAO).
    /// @param _timelock The TimelockController that controls treasury and critical operations.
    constructor(IVotes _token, TimelockController _timelock)
        Governor("InsuranceGovernor")
        GovernorSettings(uint48(1 days), uint32(1 weeks), 100_000e18)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(_timelock)
    {}

    // ── EIP-6372: Timestamp clock mode ──────────────────────────────

    /// @notice Returns the current timestamp as the governance clock.
    /// @dev Overrides GovernorVotes default (which delegates to token.clock()).
    ///      Uses block.timestamp directly for clarity and L2 compatibility.
    function clock() public view override(Governor, GovernorVotes) returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice Machine-readable clock mode description per EIP-6372.
    /// @return "mode=timestamp" indicating timestamp-based governance timing.
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override(Governor, GovernorVotes) returns (string memory) {
        return "mode=timestamp";
    }

    // ── Override resolution (Governor + extensions diamond) ─────────

    /// @inheritdoc GovernorSettings
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /// @inheritdoc GovernorSettings
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /// @inheritdoc GovernorSettings
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /// @inheritdoc GovernorVotesQuorumFraction
    function quorum(uint256 timepoint) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(timepoint);
    }

    /// @inheritdoc GovernorTimelockControl
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /// @inheritdoc GovernorTimelockControl
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @inheritdoc GovernorTimelockControl
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorTimelockControl
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorTimelockControl
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @inheritdoc GovernorTimelockControl
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
