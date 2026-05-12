// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {PolicyNFT} from "../src/PolicyNFT.sol";
import {PolicyFactory} from "../src/PolicyFactory.sol";

/// @title Step1_Deploy
/// @notice Deployment script for Step 1 foundation contracts:
///         GovernanceToken, PolicyNFT, and PolicyFactory.
contract Step1Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("---");

        vm.startBroadcast(deployerPrivateKey);

        // 1. GovernanceToken
        GovernanceToken token = new GovernanceToken(deployer);
        console.log("GovernanceToken deployed at:", address(token));

        // 2. PolicyNFT
        PolicyNFT policyNFT = new PolicyNFT("https://api.insuredao.io/policy/", deployer);
        // Grant MINTER_ROLE to deployer as placeholder until InsurancePool is deployed
        policyNFT.grantRole(policyNFT.MINTER_ROLE(), deployer);
        console.log("PolicyNFT deployed at:", address(policyNFT));

        // 3. PolicyFactory
        PolicyFactory factory = new PolicyFactory(deployer);
        console.log("PolicyFactory deployed at:", address(factory));

        vm.stopBroadcast();

        console.log("---");
        console.log("Step 1 deployment complete.");
    }
}
