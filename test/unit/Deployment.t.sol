// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSM3Deploy } from "deploy/PSM3Deploy.sol";
import { PSM3Init }   from "deploy/PSM3Init.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMDeployTests is PSMTestBase {

    function test_deploy() public {
        psm = PSM3(PSM3Deploy.deploy(
            address(dai),
            address(usdc),
            address(sDai),
            address(rateProvider)
        ));

        assertEq(address(psm.asset0()),       address(dai));
        assertEq(address(psm.asset1()),       address(usdc));
        assertEq(address(psm.asset2()),       address(sDai));
        assertEq(address(psm.rateProvider()), address(rateProvider));
    }

    function test_init() public {
        deal(address(dai), address(this), 1e18);

        psm = PSM3(PSM3Deploy.deploy(
            address(dai),
            address(usdc),
            address(sDai),
            address(rateProvider)
        ));

        assertEq(dai.allowance(address(this), address(psm)), 0);

        assertEq(dai.balanceOf(address(this)), 1e18);
        assertEq(dai.balanceOf(address(psm)),  0);

        assertEq(psm.totalAssets(),         0);
        assertEq(psm.totalShares(),         0);
        assertEq(psm.shares(address(this)), 0);
        assertEq(psm.shares(address(0)),    0);

        PSM3Init.init(address(psm), address(dai));

        assertEq(dai.allowance(address(this), address(psm)), 0);

        assertEq(dai.balanceOf(address(this)), 0);
        assertEq(dai.balanceOf(address(psm)),  1e18);

        assertEq(psm.totalAssets(),         1e18);
        assertEq(psm.totalShares(),         1e18);
        assertEq(psm.shares(address(this)), 0);
        assertEq(psm.shares(address(0)),    1e18);
    }

}
