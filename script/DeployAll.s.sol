// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {PolicyNFT} from "../src/PolicyNFT.sol";
import {PolicyFactory} from "../src/PolicyFactory.sol";
import {UnderwriterVault} from "../src/UnderwriterVault.sol";
import {CollateralManager} from "../src/CollateralManager.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {InsuranceGovernor} from "../src/governance/InsuranceGovernor.sol";
import {InsuranceTreasury} from "../src/governance/InsuranceTreasury.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @title DeployAll
/// @notice Idempotent full deployment script for the InsureDAO protocol on Arbitrum Sepolia.
/// @dev Deployment order enforces dependency resolution. All deployed addresses are
///      written to deployments/arbitrum-sepolia.json at the end.
///
///      Usage:
///        forge script script/DeployAll.s.sol --rpc-url $ARBITRUM_SEPOLIA_RPC \
///          --broadcast --verify --etherscan-api-key $ARBISCAN_API_KEY -vvvv
contract DeployAll is Script {
    struct Deployed {
        address token;
        address timelock;
        address governor;
        address usdc;
        address vault;
        address cm;
        address poolImpl;
        address poolProxy;
        address nft;
        address factory;
        address treasury;
        address oracle;
    }

    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        console.log("=== InsureDAO Full Deployment ===");
        console.log("Deployer:", deployer);

        Deployed memory d;
        d.oracle = vm.envOr("ORACLE_ADDRESS", vm.envOr("CHAINLINK_ETH_USD_FEED", address(0)));

        vm.startBroadcast(pk);

        d = _deployCore(deployer, d);
        _configureRoles(d);

        vm.stopBroadcast();

        _writeDeploymentJson(d);

        console.log("=== Deployment complete ===");
    }

    function _deployCore(address deployer, Deployed memory d) internal returns (Deployed memory) {
        // 1. GovernanceToken
        GovernanceToken token = new GovernanceToken(deployer);
        d.token = address(token);
        console.log("1.  GovernanceToken:", d.token);

        // 2. TimelockController (2-day delay)
        {
            address[] memory empty = new address[](0);
            TimelockController tl = new TimelockController(2 days, empty, empty, deployer);
            d.timelock = address(tl);
            console.log("2.  TimelockController:", d.timelock);

            // 3. InsuranceGovernor
            InsuranceGovernor gov = new InsuranceGovernor(IVotes(d.token), tl);
            d.governor = address(gov);
            console.log("3.  InsuranceGovernor:", d.governor);

            // 4-6. Timelock role setup
            tl.grantRole(tl.PROPOSER_ROLE(), d.governor);
            tl.grantRole(tl.EXECUTOR_ROLE(), address(0));
            tl.grantRole(tl.CANCELLER_ROLE(), d.governor);
            tl.renounceRole(tl.DEFAULT_ADMIN_ROLE(), deployer);
            console.log("4-6. Timelock roles configured");
        }

        // 7. USDC
        {
            address existingUsdc = vm.envOr("USDC_ADDRESS", address(0));
            if (existingUsdc == address(0)) {
                MockERC20 mock = new MockERC20("USD Coin", "USDC", 6);
                d.usdc = address(mock);
                console.log("7.  MockUSDC (testnet):", d.usdc);
            } else {
                d.usdc = existingUsdc;
                console.log("7.  USDC (existing):", d.usdc);
            }
        }

        // 8-9. Vault & CollateralManager
        {
            UnderwriterVault v = new UnderwriterVault(IERC20(d.usdc), deployer);
            d.vault = address(v);
            console.log("8.  UnderwriterVault:", d.vault);

            CollateralManager c = new CollateralManager(IERC20(d.usdc), deployer);
            d.cm = address(c);
            console.log("9.  CollateralManager:", d.cm);
        }

        // 10. PolicyNFT (must deploy before InsurancePool which needs its address)
        {
            PolicyNFT n = new PolicyNFT("https://api.insuredao.io/policy/", deployer);
            d.nft = address(n);
            console.log("10. PolicyNFT:", d.nft);
        }

        // 11. InsurancePool (UUPS proxy)
        {
            InsurancePool impl = new InsurancePool();
            d.poolImpl = address(impl);

            bytes memory initData = abi.encodeWithSelector(
                InsurancePool.initialize.selector, d.vault, d.cm, d.nft, d.oracle, d.usdc, deployer
            );
            ERC1967Proxy px = new ERC1967Proxy(d.poolImpl, initData);
            d.poolProxy = address(px);
            console.log("11. InsurancePool impl:", d.poolImpl);
            console.log("    InsurancePool proxy:", d.poolProxy);
        }

        // 13. PolicyFactory
        {
            PolicyFactory f = new PolicyFactory(deployer);
            d.factory = address(f);
            console.log("13. PolicyFactory:", d.factory);
        }

        // 14. InsuranceTreasury (admin = timelock)
        {
            InsuranceTreasury t = new InsuranceTreasury(d.timelock);
            d.treasury = address(t);
            console.log("14. InsuranceTreasury:", d.treasury);
        }

        return d;
    }

    function _configureRoles(Deployed memory d) internal {
        UnderwriterVault vault = UnderwriterVault(d.vault);
        vault.grantRole(vault.PREMIUM_DEPOSITOR_ROLE(), d.poolProxy);

        CollateralManager cm = CollateralManager(d.cm);
        cm.grantRole(cm.POOL_ROLE(), d.poolProxy);

        PolicyNFT nft = PolicyNFT(d.nft);
        nft.grantRole(nft.MINTER_ROLE(), d.poolProxy);
        nft.grantRole(nft.BURNER_ROLE(), d.poolProxy);

        console.log("16. All roles configured on InsurancePool");
    }

    function _writeDeploymentJson(Deployed memory d) internal {
        string memory json = "deploy";
        json = vm.serializeAddress(json, "governanceToken", d.token);
        json = vm.serializeAddress(json, "timelockController", d.timelock);
        json = vm.serializeAddress(json, "insuranceGovernor", d.governor);
        json = vm.serializeAddress(json, "usdc", d.usdc);
        json = vm.serializeAddress(json, "underwriterVault", d.vault);
        json = vm.serializeAddress(json, "collateralManager", d.cm);
        json = vm.serializeAddress(json, "insurancePoolImpl", d.poolImpl);
        json = vm.serializeAddress(json, "insurancePoolProxy", d.poolProxy);
        json = vm.serializeAddress(json, "policyNFT", d.nft);
        json = vm.serializeAddress(json, "policyFactory", d.factory);
        json = vm.serializeAddress(json, "insuranceTreasury", d.treasury);
        json = vm.serializeAddress(json, "oracle", d.oracle);

        string memory path = string.concat(vm.projectRoot(), "/deployments/arbitrum-sepolia.json");
        vm.writeJson(json, path);
        console.log("Addresses written to deployments/arbitrum-sepolia.json");
    }
}
