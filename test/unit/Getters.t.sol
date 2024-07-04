// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { PSM3Harness } from "test/unit/harnesses/PSM3Harness.sol";

contract PSMHarnessTests is PSMTestBase {

    PSM3Harness psmHarness;

    function setUp() public override {
        super.setUp();
        psmHarness = new PSM3Harness(
            address(dai),
            address(usdc),
            address(sDai),
            address(rateProvider)
        );
    }

    function test_getAsset0Value() public view {
        assertEq(psmHarness.getAsset0Value(1), 1);
        assertEq(psmHarness.getAsset0Value(2), 2);
        assertEq(psmHarness.getAsset0Value(3), 3);

        assertEq(psmHarness.getAsset0Value(100e18), 100e18);
        assertEq(psmHarness.getAsset0Value(200e18), 200e18);
        assertEq(psmHarness.getAsset0Value(300e18), 300e18);

        assertEq(psmHarness.getAsset0Value(100_000_000_000e18), 100_000_000_000e18);
        assertEq(psmHarness.getAsset0Value(200_000_000_000e18), 200_000_000_000e18);
        assertEq(psmHarness.getAsset0Value(300_000_000_000e18), 300_000_000_000e18);
    }

    function testFuzz_getAsset0Value(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(psmHarness.getAsset0Value(amount), amount);
    }

    function test_getAsset1Value() public view {
        assertEq(psmHarness.getAsset1Value(1), 1e12);
        assertEq(psmHarness.getAsset1Value(2), 2e12);
        assertEq(psmHarness.getAsset1Value(3), 3e12);

        assertEq(psmHarness.getAsset1Value(100e6), 100e18);
        assertEq(psmHarness.getAsset1Value(200e6), 200e18);
        assertEq(psmHarness.getAsset1Value(300e6), 300e18);

        assertEq(psmHarness.getAsset1Value(100_000_000_000e6), 100_000_000_000e18);
        assertEq(psmHarness.getAsset1Value(200_000_000_000e6), 200_000_000_000e18);
        assertEq(psmHarness.getAsset1Value(300_000_000_000e6), 300_000_000_000e18);
    }

    function testFuzz_getAsset1Value(uint256 amount) public view {
        amount = _bound(amount, 0, 1e45);

        assertEq(psmHarness.getAsset1Value(amount), amount * 1e12);
    }

    function test_getAsset2Value() public {
        assertEq(psmHarness.getAsset2Value(1), 1);
        assertEq(psmHarness.getAsset2Value(2), 2);
        assertEq(psmHarness.getAsset2Value(3), 3);
        assertEq(psmHarness.getAsset2Value(4), 5);

        assertEq(psmHarness.getAsset2Value(1e18), 1.25e18);
        assertEq(psmHarness.getAsset2Value(2e18), 2.5e18);
        assertEq(psmHarness.getAsset2Value(3e18), 3.75e18);
        assertEq(psmHarness.getAsset2Value(4e18), 5e18);

        rateProvider.__setConversionRate(1.6e27);

        assertEq(psmHarness.getAsset2Value(1), 1);
        assertEq(psmHarness.getAsset2Value(2), 3);
        assertEq(psmHarness.getAsset2Value(3), 4);
        assertEq(psmHarness.getAsset2Value(4), 6);

        assertEq(psmHarness.getAsset2Value(1e18), 1.6e18);
        assertEq(psmHarness.getAsset2Value(2e18), 3.2e18);
        assertEq(psmHarness.getAsset2Value(3e18), 4.8e18);
        assertEq(psmHarness.getAsset2Value(4e18), 6.4e18);

        rateProvider.__setConversionRate(0.8e27);

        assertEq(psmHarness.getAsset2Value(1), 0);
        assertEq(psmHarness.getAsset2Value(2), 1);
        assertEq(psmHarness.getAsset2Value(3), 2);
        assertEq(psmHarness.getAsset2Value(4), 3);

        assertEq(psmHarness.getAsset2Value(1e18), 0.8e18);
        assertEq(psmHarness.getAsset2Value(2e18), 1.6e18);
        assertEq(psmHarness.getAsset2Value(3e18), 2.4e18);
        assertEq(psmHarness.getAsset2Value(4e18), 3.2e18);
    }

    function testFuzz_getAsset2Value(uint256 conversionRate, uint256 amount) public {
        conversionRate = _bound(conversionRate, 0, 1000e27);
        amount         = _bound(amount,         0, SDAI_TOKEN_MAX);

        rateProvider.__setConversionRate(conversionRate);

        assertEq(psmHarness.getAsset2Value(amount), amount * conversionRate / 1e27);
    }

    function test_getAssetValue() public view {
        assertEq(psmHarness.getAssetValue(address(dai), 1), psmHarness.getAsset0Value(1));
        assertEq(psmHarness.getAssetValue(address(dai), 2), psmHarness.getAsset0Value(2));
        assertEq(psmHarness.getAssetValue(address(dai), 3), psmHarness.getAsset0Value(3));

        assertEq(psmHarness.getAssetValue(address(dai), 1e18), psmHarness.getAsset0Value(1e18));
        assertEq(psmHarness.getAssetValue(address(dai), 2e18), psmHarness.getAsset0Value(2e18));
        assertEq(psmHarness.getAssetValue(address(dai), 3e18), psmHarness.getAsset0Value(3e18));

        assertEq(psmHarness.getAssetValue(address(usdc), 1), psmHarness.getAsset1Value(1));
        assertEq(psmHarness.getAssetValue(address(usdc), 2), psmHarness.getAsset1Value(2));
        assertEq(psmHarness.getAssetValue(address(usdc), 3), psmHarness.getAsset1Value(3));

        assertEq(psmHarness.getAssetValue(address(usdc), 1e6), psmHarness.getAsset1Value(1e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 2e6), psmHarness.getAsset1Value(2e6));
        assertEq(psmHarness.getAssetValue(address(usdc), 3e6), psmHarness.getAsset1Value(3e6));

        assertEq(psmHarness.getAssetValue(address(sDai), 1), psmHarness.getAsset2Value(1));
        assertEq(psmHarness.getAssetValue(address(sDai), 2), psmHarness.getAsset2Value(2));
        assertEq(psmHarness.getAssetValue(address(sDai), 3), psmHarness.getAsset2Value(3));

        assertEq(psmHarness.getAssetValue(address(sDai), 1e18), psmHarness.getAsset2Value(1e18));
        assertEq(psmHarness.getAssetValue(address(sDai), 2e18), psmHarness.getAsset2Value(2e18));
        assertEq(psmHarness.getAssetValue(address(sDai), 3e18), psmHarness.getAsset2Value(3e18));
    }

    function testFuzz_getAssetValue(uint256 amount) public view {
        amount = _bound(amount, 0, SDAI_TOKEN_MAX);

        assertEq(psmHarness.getAssetValue(address(dai),  amount), psmHarness.getAsset0Value(amount));
        assertEq(psmHarness.getAssetValue(address(usdc), amount), psmHarness.getAsset1Value(amount));
        assertEq(psmHarness.getAssetValue(address(sDai), amount), psmHarness.getAsset2Value(amount));
    }

    function test_getAssetValue_zeroAddress() public {
        vm.expectRevert("PSM3/invalid-asset");
        psmHarness.getAssetValue(address(0), 1);
    }

}

contract GetPsmTotalValueTests is PSMTestBase {

    function test_totalAssets_balanceChanges() public {
        dai.mint(address(psm), 1e18);

        assertEq(psm.totalAssets(), 1e18);

        usdc.mint(address(psm), 1e6);

        assertEq(psm.totalAssets(), 2e18);

        sDai.mint(address(psm), 1e18);

        assertEq(psm.totalAssets(), 3.25e18);

        dai.burn(address(psm), 1e18);

        assertEq(psm.totalAssets(), 2.25e18);

        usdc.burn(address(psm), 1e6);

        assertEq(psm.totalAssets(), 1.25e18);

        sDai.burn(address(psm), 1e18);

        assertEq(psm.totalAssets(), 0);
    }

    function test_totalAssets_conversionRateChanges() public {
        assertEq(psm.totalAssets(), 0);

        dai.mint(address(psm),  1e18);
        usdc.mint(address(psm), 1e6);
        sDai.mint(address(psm), 1e18);

        assertEq(psm.totalAssets(), 3.25e18);

        rateProvider.__setConversionRate(1.5e27);

        assertEq(psm.totalAssets(), 3.5e18);

        rateProvider.__setConversionRate(0.8e27);

        assertEq(psm.totalAssets(), 2.8e18);
    }

    function test_totalAssets_bothChange() public {
        assertEq(psm.totalAssets(), 0);

        dai.mint(address(psm),  1e18);
        usdc.mint(address(psm), 1e6);
        sDai.mint(address(psm), 1e18);

        assertEq(psm.totalAssets(), 3.25e18);

        rateProvider.__setConversionRate(1.5e27);

        assertEq(psm.totalAssets(), 3.5e18);

        sDai.mint(address(psm), 1e18);

        assertEq(psm.totalAssets(), 5e18);
    }

    function testFuzz_totalAssets(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        daiAmount      = _bound(daiAmount,      0,         DAI_TOKEN_MAX);
        usdcAmount     = _bound(usdcAmount,     0,         USDC_TOKEN_MAX);
        sDaiAmount     = _bound(sDaiAmount,     0,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);

        dai.mint(address(psm),  daiAmount);
        usdc.mint(address(psm), usdcAmount);
        sDai.mint(address(psm), sDaiAmount);

        rateProvider.__setConversionRate(conversionRate);

        assertEq(
            psm.totalAssets(),
            daiAmount + (usdcAmount * 1e12) + (sDaiAmount * conversionRate / 1e27)
        );
    }

}
