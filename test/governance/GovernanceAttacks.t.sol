// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/GovernanceToken.sol";
import {InsuranceGovernor} from "../../src/governance/InsuranceGovernor.sol";
import {InsuranceTreasury} from "../../src/governance/InsuranceTreasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @title GovernanceAttacksTest
/// @notice Tests proving the governance design defends against flash loan attacks,
///         quorum manipulation, and proposal spam. Required by §6 audit report.
contract GovernanceAttacksTest is Test {
    GovernanceToken token;
    TimelockController timelock;
    InsuranceGovernor governor;
    InsuranceTreasury treasury;
    MockERC20 usdc;

    address deployer = makeAddr("deployer");
    address attacker = makeAddr("attacker");
    address voter1 = makeAddr("voter1");
    address recipient = makeAddr("recipient");

    function setUp() public {
        vm.warp(100_000);

        vm.startPrank(deployer);

        token = new GovernanceToken(deployer);

        address[] memory emptyArr = new address[](0);
        timelock = new TimelockController(2 days, emptyArr, emptyArr, deployer);

        governor = new InsuranceGovernor(IVotes(address(token)), timelock);

        treasury = new InsuranceTreasury(address(timelock));
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdc.mint(address(treasury), 1_000_000e6);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.transfer(voter1, 3_000_000e18);

        vm.stopPrank();

        vm.prank(voter1);
        token.delegate(voter1);
        vm.prank(deployer);
        token.delegate(deployer);

        vm.warp(block.timestamp + 2);
    }

    /// @notice Flash loan attack: attacker borrows tokens and tries to propose in the
    ///         same block. Blocked because GovernorVotes uses getPastVotes(clock() - 1),
    ///         and the delegation checkpoint at the current timestamp isn't visible yet.
    function testFlashLoanAttack_Blocked() public {
        // Attacker receives tokens (simulates flash loan borrow)
        vm.prank(deployer);
        token.transfer(attacker, 200_000e18);

        // Attacker delegates in the same timestamp
        vm.prank(attacker);
        token.delegate(attacker);

        // In the SAME timestamp, attempt to propose
        // Governor.propose checks getVotes(proposer, clock() - 1)
        // Since delegation just happened at clock(), getPastVotes(attacker, clock()-1) = 0
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _buildProposal(100e6);

        vm.prank(attacker);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, description);
    }

    /// @notice Quorum protection: a proposal where only a tiny fraction of supply votes
    ///         FOR does not pass, even if all votes are in favor. Quorum (4%) must be met.
    function testQuorum_NotReached_ProposalDefeated() public {
        // Give a tiny voter some tokens (below quorum threshold)
        address tinyVoter = makeAddr("tinyVoter");
        vm.prank(deployer);
        token.transfer(tinyVoter, 150_000e18); // 1.5% of 10M — above threshold but below 4% quorum

        vm.prank(tinyVoter);
        token.delegate(tinyVoter);
        vm.warp(block.timestamp + 2);

        // Propose (tinyVoter has > proposalThreshold)
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _buildProposal(100e6);

        vm.prank(tinyVoter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Skip voting delay
        vm.warp(block.timestamp + 1 days + 1);

        // Only tinyVoter votes FOR (1.5% of supply, below 4% quorum)
        vm.prank(tinyVoter);
        governor.castVote(proposalId, 1);

        // Skip voting period
        vm.warp(block.timestamp + 1 weeks + 1);

        // Proposal should be Defeated (quorum not reached)
        assertEq(
            uint8(governor.state(proposalId)),
            uint8(IGovernor.ProposalState.Defeated),
            "proposal should be defeated when quorum is not reached"
        );
    }

    /// @notice Proposal spam protection: an address with 0 tokens cannot create proposals
    ///         due to the proposalThreshold (1% = 100,000 IDAO).
    function testProposalSpam_ThresholdProtection() public {
        address spammer = makeAddr("spammer");

        // Spammer has 0 tokens
        assertEq(token.balanceOf(spammer), 0);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        ) = _buildProposal(100e6);

        vm.prank(spammer);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, description);
    }

    // ─── Helpers ──────────────────────────────────────────────────

    function _buildProposal(uint256 amount)
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory description
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(InsuranceTreasury.withdrawERC20, (address(usdc), recipient, amount));
        description = "Governance attack test proposal";
    }
}
