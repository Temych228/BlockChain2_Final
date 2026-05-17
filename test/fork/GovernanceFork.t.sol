// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/GovernanceToken.sol";
import {InsuranceGovernor} from "../../src/governance/InsuranceGovernor.sol";
import {InsuranceTreasury} from "../../src/governance/InsuranceTreasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title GovernanceForkTest
/// @notice Runs the full governance lifecycle on a fork to verify real-network conditions.
/// @dev Run with: ARBITRUM_RPC_URL=<rpc> forge test --mc GovernanceForkTest --fork-url $ARBITRUM_RPC_URL
contract GovernanceForkTest is Test {
    // Native USDC on Arbitrum One
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    GovernanceToken token;
    TimelockController timelock;
    InsuranceGovernor governor;
    InsuranceTreasury treasury;

    address deployer = makeAddr("deployer");
    address proposer = makeAddr("proposer");
    address voter = makeAddr("voter");
    address recipient = makeAddr("recipient");

    function setUp() public {
        try vm.activeFork() returns (uint256) {}
        catch {
            vm.skip(true);
        }

        vm.warp(100_000);

        vm.startPrank(deployer);

        token = new GovernanceToken(deployer);

        address[] memory emptyArr = new address[](0);
        timelock = new TimelockController(2 days, emptyArr, emptyArr, deployer);

        governor = new InsuranceGovernor(IVotes(address(token)), timelock);

        treasury = new InsuranceTreasury(address(timelock));

        // Fund treasury with real USDC
        deal(USDC, address(treasury), 100_000e6);

        // Setup Timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // Distribute tokens
        token.transfer(proposer, 200_000e18);
        token.transfer(voter, 5_000_000e18);

        vm.stopPrank();

        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter);
        token.delegate(voter);

        vm.warp(block.timestamp + 2);
    }

    /// @notice Full governance cycle on a fork with real USDC: propose → vote → queue → execute.
    function test_FullGovernanceCycleOnFork() public {
        // Build proposal: withdraw 1000 USDC from treasury
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(InsuranceTreasury.withdrawERC20, (USDC, recipient, 1_000e6));
        string memory desc = "Transfer 1000 USDC from treasury on fork";

        // Propose
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // Skip voting delay
        vm.warp(block.timestamp + 1 days + 1);

        // Vote
        vm.prank(voter);
        governor.castVote(proposalId, 1);

        // Skip voting period
        vm.warp(block.timestamp + 1 weeks + 1);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // Queue
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);

        // Skip timelock delay
        vm.warp(block.timestamp + 2 days + 1);

        // Execute
        uint256 recipientBalBefore = IERC20(USDC).balanceOf(recipient);
        governor.execute(targets, values, calldatas, descHash);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
        assertEq(IERC20(USDC).balanceOf(recipient) - recipientBalBefore, 1_000e6);
    }
}
