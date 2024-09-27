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
        new PSM3(address(0), address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_invalidUsdc() public {
        vm.expectRevert("PSM3/invalid-usdc");
        new PSM3(owner, address(0), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_invalidUsds() public {
        vm.expectRevert("PSM3/invalid-usds");
        new PSM3(owner, address(usdc), address(0), address(susds), address(rateProvider));
    }

    function test_constructor_invalidSUsds() public {
        vm.expectRevert("PSM3/invalid-susds");
        new PSM3(owner, address(usdc), address(usds), address(0), address(rateProvider));
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("PSM3/invalid-rateProvider");
        new PSM3(owner, address(usdc), address(usds), address(susds), address(0));
    }

    function test_constructor_usdcUsdsMatch() public {
        vm.expectRevert("PSM3/usdc-usds-same");
        new PSM3(owner, address(usdc), address(usdc), address(susds), address(rateProvider));
    }

    function test_constructor_usdcSUsdsMatch() public {
        vm.expectRevert("PSM3/usdc-susds-same");
        new PSM3(owner, address(usdc), address(usds), address(usdc), address(rateProvider));
    }

    function test_constructor_usdsSUsdsMatch() public {
        vm.expectRevert("PSM3/usds-susds-same");
        new PSM3(owner, address(usdc), address(usds), address(usds), address(rateProvider));
    }

    function test_constructor_rateProviderZero() public {
        MockRateProvider(address(rateProvider)).__setConversionRate(0);
        vm.expectRevert("PSM3/rate-provider-returns-zero");
        new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_usdcDecimalsToHighBoundary() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 19);

        vm.expectRevert("PSM3/usdc-precision-too-high");
        new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        usdc = new MockERC20("USDC", "USDC", 18);

        new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor_usdsDecimalsToHighBoundary() public {
        MockERC20 usds = new MockERC20("USDS", "USDS", 19);

        vm.expectRevert("PSM3/usds-precision-too-high");
        new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        usds = new MockERC20("USDS", "USDS", 18);

        new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));
    }

    function test_constructor() public {
        // Deploy new PSM to get test coverage
        psm = new PSM3(owner, address(usdc), address(usds), address(susds), address(rateProvider));

        assertEq(address(psm.owner()),        address(owner));
        assertEq(address(psm.usdc()),         address(usdc));
        assertEq(address(psm.usds()),         address(usds));
        assertEq(address(psm.susds()),        address(susds));
        assertEq(address(psm.rateProvider()), address(rateProvider));
    }

}
