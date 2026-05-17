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

/// @title GovernorLifecycleTest
/// @notice End-to-end governance tests: propose → vote → queue → execute lifecycle,
///         plus edge cases for threshold, deadline, and timelock enforcement.
contract GovernorLifecycleTest is Test {
    GovernanceToken token;
    TimelockController timelock;
    InsuranceGovernor governor;
    InsuranceTreasury treasury;
    MockERC20 usdc;

    address deployer = makeAddr("deployer");
    address proposer = makeAddr("proposer");
    address voter1 = makeAddr("voter1");
    address voter2 = makeAddr("voter2");
    address voter3 = makeAddr("voter3");
    address recipient = makeAddr("recipient");

    function setUp() public {
        vm.warp(100_000);

        vm.startPrank(deployer);

        // 1. Deploy GovernanceToken (10M minted to deployer)
        token = new GovernanceToken(deployer);

        // 2. Deploy TimelockController with 2-day delay
        address[] memory emptyArr = new address[](0);
        timelock = new TimelockController(2 days, emptyArr, emptyArr, deployer);

        // 3. Deploy InsuranceGovernor
        governor = new InsuranceGovernor(IVotes(address(token)), timelock);

        // 4. Deploy InsuranceTreasury (admin = timelock)
        treasury = new InsuranceTreasury(address(timelock));

        // 5. Deploy mock USDC and fund treasury
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdc.mint(address(treasury), 1_000_000e6);

        // 6. Setup Timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // anyone can execute
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // 7. Distribute tokens
        token.transfer(proposer, 200_000e18); // 2% — above 1% threshold
        token.transfer(voter1, 3_000_000e18); // 30%
        token.transfer(voter2, 2_000_000e18); // 20%
        token.transfer(voter3, 500_000e18); // 5%

        vm.stopPrank();

        // 8. Delegate voting power
        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter1);
        token.delegate(voter1);
        vm.prank(voter2);
        token.delegate(voter2);
        vm.prank(voter3);
        token.delegate(voter3);
        vm.prank(deployer);
        token.delegate(deployer);

        // Advance time so delegation checkpoints are in the past
        vm.warp(block.timestamp + 2);
    }

    // ═══════════════════════════════════════════════════════════════
    // Full Lifecycle: propose → vote → queue → execute
    // ═══════════════════════════════════════════════════════════════

    function testFullGovernanceLifecycle() public {
        // 1. PROPOSE: treasury.withdrawERC20(usdc, recipient, 10_000 USDC)
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _buildWithdrawProposal(10_000e6);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // 2. WAIT: skip voting delay (1 day)
        vm.warp(block.timestamp + 1 days + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // 3. VOTE: 3 voters cast votes (2 for, 1 against)
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // For
        vm.prank(voter2);
        governor.castVote(proposalId, 1); // For
        vm.prank(voter3);
        governor.castVote(proposalId, 0); // Against

        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = governor.proposalVotes(proposalId);
        assertGt(forVotes, againstVotes, "for votes should exceed against");
        assertGt(
            forVotes + abstainVotes, governor.quorum(governor.proposalSnapshot(proposalId)), "quorum should be reached"
        );

        // 4. WAIT: skip voting period (1 week)
        vm.warp(block.timestamp + 1 weeks + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // 5. QUEUE: schedule in Timelock
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // 6. WAIT: skip Timelock delay (2 days)
        vm.warp(block.timestamp + 2 days + 1);

        // 7. EXECUTE
        uint256 treasuryBalBefore = usdc.balanceOf(address(treasury));
        uint256 recipientBalBefore = usdc.balanceOf(recipient);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertEq(usdc.balanceOf(address(treasury)), treasuryBalBefore - 10_000e6);
        assertEq(usdc.balanceOf(recipient), recipientBalBefore + 10_000e6);
    }

    // ═══════════════════════════════════════════════════════════════
    // Edge cases
    // ═══════════════════════════════════════════════════════════════

    function testProposal_BelowThreshold_Reverts() public {
        address nobody = makeAddr("nobody");

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _buildWithdrawProposal(100e6);

        vm.prank(nobody);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, description);
    }

    function testVote_AfterDeadline_Reverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _buildWithdrawProposal(100e6);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Skip past voting delay + voting period
        vm.warp(block.timestamp + 1 days + 1 weeks + 2);

        vm.prank(voter1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function testExecute_BeforeTimelockDelay_Reverts() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
            _buildWithdrawProposal(100e6);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Pass voting
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);
        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        // Skip voting period
        vm.warp(block.timestamp + 1 weeks + 1);

        // Queue
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Try to execute immediately — should revert (Timelock delay not elapsed)
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function testFuzz_VotingPower(uint96 delegatedAmount) public {
        delegatedAmount = uint96(bound(delegatedAmount, 1, 1_000_000e18));

        address newVoter = makeAddr("newVoter");

        vm.prank(deployer);
        token.mint(newVoter, delegatedAmount);

        vm.prank(newVoter);
        token.delegate(newVoter);

        vm.warp(block.timestamp + 1);

        assertEq(token.getVotes(newVoter), delegatedAmount);
    }

    // ─── Helpers ──────────────────────────────────────────────────

    function _buildWithdrawProposal(uint256 amount)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(InsuranceTreasury.withdrawERC20, (address(usdc), recipient, amount));
        description = string.concat("Transfer ", vm.toString(amount), " USDC from treasury");
    }
}
