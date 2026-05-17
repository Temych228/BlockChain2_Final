// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

/// @title SeedTestTokens
/// @notice Mints USDC and IDAO tokens to a target wallet for frontend testing.
///         Also delegates IDAO tokens so the wallet has voting power immediately.
/// @dev Usage:
///   SEED_WALLET=0xYourAddress forge script script/SeedTestTokens.s.sol \
///     --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast -vvvv
contract SeedTestTokens is Script {
    function run() external {
        uint256 deployerPk = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        address target = vm.envAddress("SEED_WALLET");

        address usdc = 0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C;
        address idao = 0xb06eCBf6dC4Ca68716b400bfC1Aacbae0d7e487f;

        uint256 usdcAmount = 10_000 * 1e6; // 10,000 USDC
        uint256 idaoAmount = 10_000 * 1e18; // 10,000 IDAO

        console.log("Seeding tokens to:", target);

        vm.startBroadcast(deployerPk);

        // Mint USDC (MockERC20 has public mint)
        MockERC20(usdc).mint(target, usdcAmount);
        console.log("Minted 10,000 USDC");

        // Mint IDAO (onlyOwner — deployer is owner)
        GovernanceToken(idao).mint(target, idaoAmount);
        console.log("Minted 10,000 IDAO");

        vm.stopBroadcast();

        console.log("Done! Connect wallet to frontend and delegate IDAO on Governance page.");
    }
}
