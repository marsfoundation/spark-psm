// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Base } from "lib/spark-address-registry/src/Base.sol";

import { PSM3Deploy } from "deploy/PSM3Deploy.sol";

contract DeployPSM3 is Script {

    function run() external {
        vm.createSelectFork(getChain("base").rpcUrl);

        console.log("Deploying PSM...");

        vm.startBroadcast();

        address psm = PSM3Deploy.deploy({
            owner        : Base.SPARK_EXECUTOR,
            usdc         : Base.USDC,
            usds         : Base.USDS,
            susds        : Base.SUSDS,
            rateProvider : Base.SSR_AUTH_ORACLE
        });

        vm.stopBroadcast();

        console.log("PSM3 deployed at:", psm);
    }

}
