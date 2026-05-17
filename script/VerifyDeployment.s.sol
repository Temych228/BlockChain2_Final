// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {UnderwriterVault} from "../src/UnderwriterVault.sol";
import {InsuranceGovernor} from "../src/governance/InsuranceGovernor.sol";
import {InsuranceTreasury} from "../src/governance/InsuranceTreasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title VerifyDeployment
/// @notice Post-deployment verification script. Reads deployment addresses from JSON
///         and validates all configuration: roles, parameters, and wiring.
/// @dev Usage:
///        forge script script/VerifyDeployment.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC -vvvv
contract VerifyDeployment is Script {
    uint256 passCount;
    uint256 failCount;

    function run() external view {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/arbitrum-sepolia.json");
        string memory json = vm.readFile(path);

        address timelockAddr = vm.parseJsonAddress(json, ".timelockController");
        address governorAddr = vm.parseJsonAddress(json, ".insuranceGovernor");
        address vaultAddr = vm.parseJsonAddress(json, ".underwriterVault");
        address poolAddr = vm.parseJsonAddress(json, ".insurancePoolProxy");
        address treasuryAddr = vm.parseJsonAddress(json, ".insuranceTreasury");
        address usdcAddr = vm.parseJsonAddress(json, ".usdc");

        TimelockController timelock = TimelockController(payable(timelockAddr));
        InsuranceGovernor governor = InsuranceGovernor(payable(governorAddr));
        UnderwriterVault vault = UnderwriterVault(vaultAddr);
        InsurancePool pool = InsurancePool(poolAddr);
        InsuranceTreasury treasury = InsuranceTreasury(payable(treasuryAddr));

        console.log("=== Post-Deployment Verification ===");
        console.log("");

        // 1. InsurancePool DEFAULT_ADMIN_ROLE holder
        _check(
            "InsurancePool admin includes deployer or Timelock",
            pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), timelockAddr) || pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), msg.sender)
        );

        // 2. TimelockController min delay == 2 days
        _check("TimelockController.getMinDelay() == 2 days", timelock.getMinDelay() == 2 days);

        // 3. InsuranceGovernor voting delay == 1 day
        _check("InsuranceGovernor.votingDelay() == 1 day", governor.votingDelay() == 1 days);

        // 4. InsuranceGovernor voting period == 1 week
        _check("InsuranceGovernor.votingPeriod() == 1 week", governor.votingPeriod() == 1 weeks);

        // 5. InsuranceGovernor quorum numerator == 4
        _check("InsuranceGovernor.quorumNumerator() == 4", governor.quorumNumerator() == 4);

        // 6. InsuranceGovernor proposal threshold == 100_000e18
        _check("InsuranceGovernor.proposalThreshold() == 100_000e18", governor.proposalThreshold() == 100_000e18);

        // 7. Timelock has PROPOSER_ROLE for Governor
        _check(
            "Timelock PROPOSER_ROLE granted to Governor", timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor))
        );

        // 8. Timelock has EXECUTOR_ROLE for address(0) (open execution)
        _check("Timelock EXECUTOR_ROLE granted to address(0)", timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));

        // 9. Deployer no longer has DEFAULT_ADMIN_ROLE on Timelock
        _check(
            "Deployer renounced DEFAULT_ADMIN_ROLE on Timelock",
            !timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender)
        );

        // 10. InsuranceTreasury admin == TimelockController
        _check(
            "InsuranceTreasury admin is TimelockController",
            treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), timelockAddr)
        );

        // 11. UnderwriterVault asset == USDC address
        _check("UnderwriterVault.asset() == USDC", vault.asset() == usdcAddr);

        console.log("");
        console.log("=== Verification complete ===");
    }

    function _check(string memory label, bool condition) internal pure {
        if (condition) {
            console.log(string.concat(unicode"✅ PASS: ", label));
        } else {
            console.log(string.concat(unicode"❌ FAIL: ", label));
        }
    }
}
