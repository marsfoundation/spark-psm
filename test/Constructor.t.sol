// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConstructorTests is PSMTestBase {

    function test_constructor_invalidAsset0() public {
        vm.expectRevert("PSM/invalid-asset0");
        new PSM(address(0), address(usdc), address(sDai), address(rateProvider), 1000);
    }

    function test_constructor_invalidAsset1() public {
        vm.expectRevert("PSM/invalid-asset1");
        new PSM(address(dai), address(0), address(sDai), address(rateProvider), 1000);
    }

    function test_constructor_invalidAsset2() public {
        vm.expectRevert("PSM/invalid-asset2");
        new PSM(address(dai), address(usdc), address(0), address(rateProvider), 1000);
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("PSM/invalid-rateProvider");
        new PSM(address(dai), address(sDai), address(usdc), address(0), 1000);
    }

    function test_constructor() public {
        // Deploy new PSM to get test coverage
        psm = new PSM(address(dai), address(usdc), address(sDai), address(rateProvider), 1000);

        assertEq(address(psm.asset0()),       address(dai));
        assertEq(address(psm.asset1()),       address(usdc));
        assertEq(address(psm.asset2()),       address(sDai));
        assertEq(address(psm.rateProvider()), address(rateProvider));

        assertEq(psm.initialBurnAmount(), 1000);
    }

}
