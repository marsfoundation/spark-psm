// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewSwapExactIn_FailureTests is PSMTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwapExactIn_invalidAssetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactIn_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(dai), address(dai), 1);
    }

    function test_previewSwapExactIn_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactIn_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(sDai), address(sDai), 1);
    }

}

contract PSMPreviewSwapExactOut_FailureTests is PSMTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwapExactOut_invalidAssetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactOut_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(dai), address(dai), 1);
    }

    function test_previewSwapExactOut_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactOut_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(sDai), address(sDai), 1);
    }

}

contract PSMPreviewSwapExactIn_DaiAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_daiToUsdc() public view {
        // assertEq(psm.previewSwapExactIn(address(dai), address(usdc), 1e12 - 1), 0);
        // assertEq(psm.previewSwapExactIn(address(dai), address(usdc), 1e12),     1);

        assertEq(psm.previewSwapExactIn(address(dai), address(usdc), 1e18), 1e6);
        assertEq(psm.previewSwapExactIn(address(dai), address(usdc), 2e18), 2e6);
        assertEq(psm.previewSwapExactIn(address(dai), address(usdc), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactIn_daiToUsdc(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, DAI_TOKEN_MAX);

        assertEq(psm.previewSwapExactIn(address(dai), address(usdc), amountIn), amountIn / 1e12);
    }

    function test_previewSwapExactIn_daiToSDai() public view {
        assertEq(psm.previewSwapExactIn(address(dai), address(sDai), 1e18), 0.8e18);
        assertEq(psm.previewSwapExactIn(address(dai), address(sDai), 2e18), 1.6e18);
        assertEq(psm.previewSwapExactIn(address(dai), address(sDai), 3e18), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_daiToSDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        assertEq(psm.previewSwapExactIn(address(dai), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_DaiAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_daiToUsdc() public view {
        assertEq(psm.previewSwapExactOut(address(dai), address(usdc), 1e6), 1e18);
        assertEq(psm.previewSwapExactOut(address(dai), address(usdc), 2e6), 2e18);
        assertEq(psm.previewSwapExactOut(address(dai), address(usdc), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_daiToUsdc(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwapExactOut(address(dai), address(usdc), amountOut), amountOut * 1e12);
    }

    function test_previewSwapExactOut_daiToSDai() public view {
        assertEq(psm.previewSwapExactOut(address(dai), address(sDai), 0.8e18), 1e18);
        assertEq(psm.previewSwapExactOut(address(dai), address(sDai), 1.6e18), 2e18);
        assertEq(psm.previewSwapExactOut(address(dai), address(sDai), 2.4e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_daiToSDai(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * conversionRate / 1e27;

        assertEq(psm.previewSwapExactOut(address(dai), address(sDai), amountOut), amountIn);
    }

}

contract PSMPreviewSwapExactIn_USDCAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_usdcToDai() public view {
        assertEq(psm.previewSwapExactIn(address(usdc), address(dai), 1e6), 1e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(dai), 2e6), 2e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(dai), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactIn_usdcToDai(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwapExactIn(address(usdc), address(dai), amountIn), amountIn * 1e12);
    }

    function test_previewSwapExactIn_usdcToSDai() public view {
        assertEq(psm.previewSwapExactIn(address(usdc), address(sDai), 1e6), 0.8e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(sDai), 2e6), 1.6e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(sDai), 3e6), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_usdcToSDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        assertEq(psm.previewSwapExactIn(address(usdc), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_USDCAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_usdcToDai() public view {
        assertEq(psm.previewSwapExactOut(address(usdc), address(dai), 1e18), 1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(dai), 2e18), 2e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(dai), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToDai(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, DAI_TOKEN_MAX);

        uint256 amountIn = psm.previewSwapExactOut(address(usdc), address(dai), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - amountOut / 1e12, 1);
    }

    function test_previewSwapExactOut_usdcToSDai() public view {
        assertEq(psm.previewSwapExactOut(address(usdc), address(sDai), 0.8e18), 1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(sDai), 1.6e18), 2e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(sDai), 2.4e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToSDai(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,     1,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        // Using raw calculation to demo rounding
        uint256 expectedAmountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 amountIn = psm.previewSwapExactOut(address(usdc), address(sDai), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

}

contract PSMPreviewSwapExactIn_SDaiAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_sDaiToDai() public view {
        assertEq(psm.previewSwapExactIn(address(sDai), address(dai), 1e18), 1.25e18);
        assertEq(psm.previewSwapExactIn(address(sDai), address(dai), 2e18), 2.5e18);
        assertEq(psm.previewSwapExactIn(address(sDai), address(dai), 3e18), 3.75e18);
    }

    function testFuzz_previewSwapExactIn_sDaiToDai(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        assertEq(psm.previewSwapExactIn(address(sDai), address(dai), amountIn), amountOut);
    }

    function test_previewSwapExactIn_sDaiToUsdc() public view {
        assertEq(psm.previewSwapExactIn(address(sDai), address(usdc), 1e18), 1.25e6);
        assertEq(psm.previewSwapExactIn(address(sDai), address(usdc), 2e18), 2.5e6);
        assertEq(psm.previewSwapExactIn(address(sDai), address(usdc), 3e18), 3.75e6);
    }

    function testFuzz_previewSwapExactIn_sDaiToUsdc(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(psm.previewSwapExactIn(address(sDai), address(usdc), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_SDaiAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_sDaiToDai() public view {
        assertEq(psm.previewSwapExactOut(address(sDai), address(dai), 1.25e18), 1e18);
        assertEq(psm.previewSwapExactOut(address(sDai), address(dai), 2.5e18),  2e18);
        assertEq(psm.previewSwapExactOut(address(sDai), address(dai), 3.75e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_sDaiToDai(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate;

        assertEq(psm.previewSwapExactOut(address(sDai), address(dai), amountOut), amountIn);
    }

    function test_previewSwapExactOut_sDaiToUsdc() public view {
        assertEq(psm.previewSwapExactOut(address(sDai), address(usdc), 1.25e6), 1e18);
        assertEq(psm.previewSwapExactOut(address(sDai), address(usdc), 2.5e6),  2e18);
        assertEq(psm.previewSwapExactOut(address(sDai), address(usdc), 3.75e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_sDaiToUsdc(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate * 1e12;

        assertEq(psm.previewSwapExactOut(address(sDai), address(usdc), amountOut), amountIn);
    }

}
