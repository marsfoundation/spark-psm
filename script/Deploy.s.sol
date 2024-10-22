// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Base } from "lib/spark-address-registry/src/Base.sol";

import { PSMDeploy } from "deploy/PSMDeploy.sol";

contract DeployMainnetFull is Script {

    address public constant ALLOCATOR_VAULT = 0x691a6c29e9e96dd897718305427Ad5D534db16BA;

    function run() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Deploying PSM...");

        vm.startBroadcast();

        address psm = PSMDeploy.deploy(({
            owner: Base.SPARK_EXECUTOR,
            usdc: Base.USDC,
            usds: Base.USDS,
            susds: Base.SUSDS,
            rateProvider: Base.RATE_PROVIDER
        }))

        vm.stopBroadcast();

        console.log("ALMProxy   deployed at", instance.almProxy);
        console.log("Controller deployed at", instance.controller);
        console.log("RateLimits deployed at", instance.rateLimits);
    }

}
