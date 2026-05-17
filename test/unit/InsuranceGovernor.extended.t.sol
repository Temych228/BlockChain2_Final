// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/GovernanceToken.sol";
import {InsuranceGovernor} from "../../src/governance/InsuranceGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @title InsuranceGovernor Extended Tests
/// @notice Validates Governor configuration, clock mode, and override functions.
contract InsuranceGovernorExtendedTest is Test {
    GovernanceToken token;
    TimelockController timelock;
    InsuranceGovernor governor;

    address deployer = makeAddr("deployer");

    function setUp() public {
        vm.warp(100_000);

        vm.startPrank(deployer);

        token = new GovernanceToken(deployer);

        address[] memory emptyArr = new address[](0);
        timelock = new TimelockController(2 days, emptyArr, emptyArr, deployer);

        governor = new InsuranceGovernor(IVotes(address(token)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        vm.stopPrank();
    }

    function test_GovernorName() public view {
        assertEq(governor.name(), "InsuranceGovernor");
    }

    function test_VotingDelay_OneDay() public view {
        assertEq(governor.votingDelay(), 1 days);
    }

    function test_VotingPeriod_OneWeek() public view {
        assertEq(governor.votingPeriod(), 1 weeks);
    }

    function test_ProposalThreshold_100kTokens() public view {
        assertEq(governor.proposalThreshold(), 100_000e18);
    }

    function test_ClockMode_Timestamp() public view {
        string memory mode = governor.CLOCK_MODE();
        assertEq(mode, "mode=timestamp");
    }

    function test_Clock_ReturnsTimestamp() public view {
        assertEq(governor.clock(), uint48(block.timestamp));
    }

    function test_Quorum_FourPercent() public {
        vm.prank(deployer);
        token.delegate(deployer);
        vm.warp(block.timestamp + 1);

        uint256 q = governor.quorum(block.timestamp - 1);
        assertEq(q, (token.totalSupply() * 4) / 100);
    }

    function test_TokenClockMode_Matches() public view {
        assertEq(token.CLOCK_MODE(), governor.CLOCK_MODE());
    }

    function test_TokenClock_ReturnsTimestamp() public view {
        assertEq(token.clock(), uint48(block.timestamp));
    }
}
