// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract PSMConstructorTests is PSMTestBase {

    function test_constructor_invalidOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new PSM3(address(0), address(dai), address(usdc), address(sDai), address(rateProvider));
    }

    function test_constructor_invalidAsset0() public {
        vm.expectRevert("PSM3/invalid-asset0");
        new PSM3(admin, address(0), address(usdc), address(sDai), address(rateProvider));
    }

    function test_constructor_invalidAsset1() public {
        vm.expectRevert("PSM3/invalid-asset1");
        new PSM3(admin, address(dai), address(0), address(sDai), address(rateProvider));
    }

    function test_constructor_invalidAsset2() public {
        vm.expectRevert("PSM3/invalid-asset2");
        new PSM3(admin, address(dai), address(usdc), address(0), address(rateProvider));
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("PSM3/invalid-rateProvider");
        new PSM3(admin, address(dai), address(usdc), address(sDai), address(0));
    }

    function test_constructor_asset0Asset1Match() public {
        vm.expectRevert("PSM3/asset0-asset1-same");
        new PSM3(admin, address(dai), address(dai), address(sDai), address(rateProvider));
    }

    function test_constructor_asset0Asset2Match() public {
        vm.expectRevert("PSM3/asset0-asset2-same");
        new PSM3(admin, address(dai), address(usdc), address(dai), address(rateProvider));
    }

    function test_constructor_asset1Asset2Match() public {
        vm.expectRevert("PSM3/asset1-asset2-same");
        new PSM3(admin, address(dai), address(usdc), address(usdc), address(rateProvider));
    }

    function test_constructor_rateProviderZero() public {
        MockRateProvider(address(rateProvider)).__setConversionRate(0);
        vm.expectRevert("PSM3/rate-provider-returns-zero");
        new PSM3(admin, address(dai), address(usdc), address(sDai), address(rateProvider));
    }

    function test_constructor_asset0DecimalsToHighBoundary() public {
        MockERC20 asset0 = new MockERC20("Asset0", "A0", 19);

        vm.expectRevert("PSM3/asset0-precision-too-high");
        new PSM3(admin, address(asset0), address(usdc), address(sDai), address(rateProvider));

        asset0 = new MockERC20("Asset0", "A0", 18);

        new PSM3(admin, address(asset0), address(usdc), address(sDai), address(rateProvider));
    }

    function test_constructor_asset1DecimalsToHighBoundary() public {
        MockERC20 asset1 = new MockERC20("Asset1", "A1", 19);

        vm.expectRevert("PSM3/asset1-precision-too-high");
        new PSM3(admin, address(dai), address(asset1), address(sDai), address(rateProvider));

        asset1 = new MockERC20("Asset1", "A1", 18);

        new PSM3(admin, address(dai), address(asset1), address(sDai), address(rateProvider));
    }

    function test_constructor() public {
        // Deploy new PSM to get test coverage
        psm = new PSM3(admin, address(dai), address(usdc), address(sDai), address(rateProvider));

        assertEq(address(psm.owner()),        address(admin));
        assertEq(address(psm.asset0()),       address(dai));
        assertEq(address(psm.asset1()),       address(usdc));
        assertEq(address(psm.asset2()),       address(sDai));
        assertEq(address(psm.rateProvider()), address(rateProvider));
    }

}
