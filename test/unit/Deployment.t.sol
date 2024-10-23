// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3Deploy } from "deploy/PSM3Deploy.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMDeployTests is PSMTestBase {

    function test_deploy() public {
        deal(address(usdc), address(this), 1e6);

        PSM3 newPsm = PSM3(PSM3Deploy.deploy(
            address(owner),
            address(usdc),
            address(usds),
            address(susds),
            address(rateProvider)
        ));

        assertEq(address(newPsm.owner()),        address(owner));
        assertEq(address(newPsm.usdc()),         address(usdc));
        assertEq(address(newPsm.usds()),         address(usds));
        assertEq(address(newPsm.susds()),        address(susds));
        assertEq(address(newPsm.rateProvider()), address(rateProvider));

        assertEq(usdc.allowance(address(this), address(newPsm)), 0);

        assertEq(usdc.balanceOf(address(this)),   0);
        assertEq(usdc.balanceOf(address(newPsm)), 1e6);

        assertEq(newPsm.totalAssets(),         1e18);
        assertEq(newPsm.totalShares(),         1e18);
        assertEq(newPsm.shares(address(this)), 0);
        assertEq(newPsm.shares(address(0)),    1e18);
    }

}
