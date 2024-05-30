// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConstructorTests is PSMTestBase {

    function test_constructor_invalidAsset0() public {
        vm.expectRevert("PSM/invalid-asset0");
        new PSM(address(0), address(sDai), address(rateProvider));
    }

    function test_constructor_invalidAsset1() public {
        vm.expectRevert("PSM/invalid-asset1");
        new PSM(address(usdc), address(0), address(rateProvider));
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("PSM/invalid-rateProvider");
        new PSM(address(sDai), address(usdc), address(0));
    }

    function test_constructor() public {
        // Deploy new PSM to get test coverage
        psm = new PSM(address(usdc), address(sDai), address(rateProvider));

        assertEq(address(psm.asset0()),       address(usdc));
        assertEq(address(psm.asset1()),       address(sDai));
        assertEq(address(psm.rateProvider()), address(rateProvider));

        assertEq(psm.asset0Precision(), 10 ** usdc.decimals());
        assertEq(psm.asset1Precision(), 10 ** sDai.decimals());
    }

}
