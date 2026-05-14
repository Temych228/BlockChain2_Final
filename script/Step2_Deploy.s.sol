// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UnderwriterVault} from "../src/UnderwriterVault.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {PolicyNFT} from "../src/PolicyNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Step2_Deploy
/// @notice Deployment script for Step 2 core protocol contracts:
///         UnderwriterVault, CollateralManager, InsurancePool (UUPS proxy).
///         Assumes Step 1 contracts (GovernanceToken, PolicyNFT, PolicyFactory) are already deployed.
contract Step2Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        // Addresses from Step 1 (replace with actual deployed addresses)
        address policyNFTAddr = vm.envOr("POLICY_NFT", address(0));
        address usdcAddr = vm.envOr("USDC_ADDRESS", address(0));
        address oracleAddr = vm.envOr("ORACLE_ADDRESS", address(0));

        console.log("Deployer:", deployer);
        console.log("---");

        vm.startBroadcast(deployerPrivateKey);

        // 1. UnderwriterVault
        UnderwriterVault vault = new UnderwriterVault(IERC20(usdcAddr), deployer);
        console.log("UnderwriterVault deployed at:", address(vault));

        // 2. CollateralManager
        CollateralManager cm = new CollateralManager(IERC20(usdcAddr), deployer);
        console.log("CollateralManager deployed at:", address(cm));

        // 3. InsurancePool (UUPS proxy)
        InsurancePool poolImpl = new InsurancePool();
        bytes memory initData = abi.encodeWithSelector(
            InsurancePool.initialize.selector,
            address(vault),
            address(cm),
            policyNFTAddr,
            oracleAddr,
            usdcAddr,
            deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(poolImpl), initData);
        console.log("InsurancePool impl deployed at:", address(poolImpl));
        console.log("InsurancePool proxy deployed at:", address(proxy));

        // 4. Set roles
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), address(proxy));
        console.log("Granted PREMIUM_DEPOSITOR_ROLE to InsurancePool proxy");

        cm.grantRole(cm.POOL_ROLE(), address(proxy));
        console.log("Granted POOL_ROLE to InsurancePool proxy");

        // Grant MINTER/BURNER on PolicyNFT to InsurancePool (if PolicyNFT is deployed)
        if (policyNFTAddr != address(0)) {
            PolicyNFT nft = PolicyNFT(policyNFTAddr);
            nft.grantRole(nft.MINTER_ROLE(), address(proxy));
            nft.grantRole(nft.BURNER_ROLE(), address(proxy));
            console.log("Granted MINTER_ROLE and BURNER_ROLE to InsurancePool proxy on PolicyNFT");
        }

        vm.stopBroadcast();

        console.log("---");
        console.log("Step 2 deployment complete.");
    }
}
