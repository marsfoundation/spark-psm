// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3Deploy } from "deploy/PSM3Deploy.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMDeployTests is PSMTestBase {

    function test_init() public {
        deal(address(dai), address(this), 1e18);

        PSM3 newPsm = PSM3(PSM3Deploy.deploy(
            address(dai),
            address(usdc),
            address(sDai),
            address(rateProvider)
        ));

        assertEq(address(newPsm.asset0()),       address(dai));
        assertEq(address(newPsm.asset1()),       address(usdc));
        assertEq(address(newPsm.asset2()),       address(sDai));
        assertEq(address(newPsm.rateProvider()), address(rateProvider));

        assertEq(dai.allowance(address(this), address(newPsm)), 0);

        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(dai.balanceOf(address(newPsm)),  1e18);

        assertEq(newPsm.totalAssets(),         1e18);
        assertEq(newPsm.totalShares(),         1e18);
        assertEq(newPsm.shares(address(this)), 0);
        assertEq(newPsm.shares(address(0)),    1e18);
    }

}
