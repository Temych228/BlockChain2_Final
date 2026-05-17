// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {InsurancePoolV2} from "../src/InsurancePoolV2.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UpgradeAndFund is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        address poolProxy = 0xF293eD1ABd74D70A012c69b15f22C20Df4c8858C;
        address usdc = 0x0F5730CdDE59df09b142072B9C9b5e4a1e894a7C;
        uint256 fundAmount = 500_000 * 1e6; // 500k USDC

        console.log("Deployer:", deployer);

        vm.startBroadcast(pk);

        // 1. Deploy new V2 implementation
        InsurancePoolV2 v2Impl = new InsurancePoolV2();
        console.log("V2 Implementation:", address(v2Impl));

        // 2. Upgrade proxy to V2 and call initializeV2
        InsurancePool(poolProxy)
            .upgradeToAndCall(address(v2Impl), abi.encodeWithSelector(InsurancePoolV2.initializeV2.selector));
        console.log("Proxy upgraded to V2");

        // 3. Add policy type 0 (in case it wasn't added or was on old deployment)
        try InsurancePoolV2(poolProxy).addPolicyType(0, 100_000 * 1e6, 1e18) {
            console.log("Policy type 0 added");
        } catch {
            console.log("Policy type 0 already exists");
        }

        // 4. Mint USDC to deployer and fund pool
        MockERC20(usdc).mint(deployer, fundAmount);
        IERC20(usdc).approve(poolProxy, fundAmount);
        InsurancePoolV2(poolProxy).fundPool(fundAmount);
        console.log("Pool funded with 500k USDC collateral");

        vm.stopBroadcast();
    }
}
