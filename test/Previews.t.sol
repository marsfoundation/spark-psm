// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewSwapFailureTests is PSMTestBase {

    function test_previewSwap_invalidAssetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwap(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwap_invalidAssetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwap(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwap_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwap(address(dai), address(dai), 1);
    }

    function test_previewSwap_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwap(address(usdc), address(usdc), 1);
    }

    function test_previewSwap_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwap(address(sDai), address(sDai), 1);
    }

}

contract PSMPreviewSwapDaiAssetInTests is PSMTestBase {

    function test_previewSwap_daiToUsdc() public view {
        assertEq(psm.previewSwap(address(dai), address(usdc), 1e12 - 1), 0);
        assertEq(psm.previewSwap(address(dai), address(usdc), 1e12),     1);

        assertEq(psm.previewSwap(address(dai), address(usdc), 1e18), 1e6);
        assertEq(psm.previewSwap(address(dai), address(usdc), 2e18), 2e6);
        assertEq(psm.previewSwap(address(dai), address(usdc), 3e18), 3e6);
    }

    function testFuzz_previewSwap_daiToUsdc(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, DAI_TOKEN_MAX);

        assertEq(psm.previewSwap(address(dai), address(usdc), amountIn), amountIn / 1e12);
    }

    function test_previewSwap_daiToSDai() public view {
        assertEq(psm.previewSwap(address(dai), address(sDai), 1e18), 0.8e18);
        assertEq(psm.previewSwap(address(dai), address(sDai), 2e18), 1.6e18);
        assertEq(psm.previewSwap(address(dai), address(sDai), 3e18), 2.4e18);
    }

    function testFuzz_previewSwap_daiToSDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        assertEq(psm.previewSwap(address(dai), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapUSDCAssetInTests is PSMTestBase {

    function test_previewSwap_usdcToDai() public view {
        assertEq(psm.previewSwap(address(usdc), address(dai), 1e6), 1e18);
        assertEq(psm.previewSwap(address(usdc), address(dai), 2e6), 2e18);
        assertEq(psm.previewSwap(address(usdc), address(dai), 3e6), 3e18);
    }

    function testFuzz_previewSwap_usdcToDai(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwap(address(usdc), address(dai), amountIn), amountIn * 1e12);
    }

    function test_previewSwap_usdcToSDai() public view {
        assertEq(psm.previewSwap(address(usdc), address(sDai), 1e6), 0.8e18);
        assertEq(psm.previewSwap(address(usdc), address(sDai), 2e6), 1.6e18);
        assertEq(psm.previewSwap(address(usdc), address(sDai), 3e6), 2.4e18);
    }

    function testFuzz_previewSwap_usdcToSDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        assertEq(psm.previewSwap(address(usdc), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapSDaiAssetInTests is PSMTestBase {

    function test_previewSwap_sDaiToDai() public view {
        assertEq(psm.previewSwap(address(sDai), address(dai), 1e18), 1.25e18);
        assertEq(psm.previewSwap(address(sDai), address(dai), 2e18), 2.5e18);
        assertEq(psm.previewSwap(address(sDai), address(dai), 3e18), 3.75e18);
    }

    function testFuzz_previewSwap_sDaiToDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        assertEq(psm.previewSwap(address(sDai), address(dai), amountIn), amountOut);
    }

    function test_previewSwap_sDaiToUsdc() public view {
        assertEq(psm.previewSwap(address(sDai), address(usdc), 1e18), 1.25e6);
        assertEq(psm.previewSwap(address(sDai), address(usdc), 2e18), 2.5e6);
        assertEq(psm.previewSwap(address(sDai), address(usdc), 3e18), 3.75e6);
    }

    function testFuzz_previewSwap_sDaiToUsdc(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(psm.previewSwap(address(sDai), address(usdc), amountIn), amountOut);
    }

}

