// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewSwapExactIn_FailureTests is PSMTestBase {

    function test_previewSwapExactIn_invalidAssetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwapExactIn_invalidAssetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(usdc), makeAddr("other-token"), 1);
    }

    function test_previewSwapExactIn_bothUsdc() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactIn_bothUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(usds), address(usds), 1);
    }

    function test_previewSwapExactIn_bothSUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactIn(address(susds), address(susds), 1);
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

    function test_previewSwapExactOut_bothUsdc() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(usds), address(usds), 1);
    }

    function test_previewSwapExactOut_bothUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(usdc), address(usdc), 1);
    }

    function test_previewSwapExactOut_bothSUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewSwapExactOut(address(susds), address(susds), 1);
    }

}

contract PSMPreviewSwapExactIn_UsdsAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_usdsToUsdc() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e18 - 1), 1e6 - 1);
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e18),     1e6);
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e18 + 1), 1e6);

        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e12 - 1), 0);
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e12),     1);

        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 1e18), 1e6);
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 2e18), 2e6);
        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactIn_usdsToUsdc(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDS_TOKEN_MAX);

        assertEq(psm.previewSwapExactIn(address(usds), address(usdc), amountIn), amountIn / 1e12);
    }

    function test_previewSwapExactIn_usdsToSUsds() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 1e18 - 1), 0.8e18 - 1);
        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 1e18),     0.8e18);
        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 1e18 + 1), 0.8e18);

        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 1e18), 0.8e18);
        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 2e18), 1.6e18);
        assertEq(psm.previewSwapExactIn(address(usds), address(susds), 3e18), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_usdsToSUsds(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        assertEq(psm.previewSwapExactIn(address(usds), address(susds), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_UsdsAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_usdsToUsdc() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 1e6 - 1), 0.999999e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 1e6),     1e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 1e6 + 1), 1.000001e18);

        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 1e6), 1e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 2e6), 2e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_usdsToUsdc(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwapExactOut(address(usds), address(usdc), amountOut), amountOut * 1e12);
    }

    function test_previewSwapExactOut_usdsToSUsds() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 1e18 - 1), 1.25e18 - 1);
        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 1e18),     1.25e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 1e18 + 1), 1.25e18 + 2);

        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 0.8e18), 1e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 1.6e18), 2e18);
        assertEq(psm.previewSwapExactOut(address(usds), address(susds), 2.4e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_usdsToSUsds(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * conversionRate / 1e27;

        uint256 amountIn = psm.previewSwapExactOut(address(usds), address(susds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

}

contract PSMPreviewSwapExactIn_USDCAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_usdcToUsds() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 1e6 - 1), 0.999999e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 1e6),     1e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 1e6 + 1), 1.000001e18);

        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 1e6), 1e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 2e6), 2e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), 3e6), 3e18);
    }

    function testFuzz_previewSwapExactIn_usdcToUsds(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwapExactIn(address(usdc), address(usds), amountIn), amountIn * 1e12);
    }

    function test_previewSwapExactIn_usdcToSUsds() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 1e6 - 1), 0.799999e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 1e6),     0.8e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 1e6 + 1), 0.8e18);

        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 1e6), 0.8e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 2e6), 1.6e18);
        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), 3e6), 2.4e18);
    }

    function testFuzz_previewSwapExactIn_usdcToSUsds(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        assertEq(psm.previewSwapExactIn(address(usdc), address(susds), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_USDCAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_usdcToUsds() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 1e18 - 1), 1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 1e18),     1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1), 1e6 + 1);

        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 1e18), 1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 2e18), 2e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(usds), 3e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToUsds(uint256 amountOut) public view {
        amountOut = _bound(amountOut, 0, USDS_TOKEN_MAX);

        uint256 amountIn = psm.previewSwapExactOut(address(usdc), address(usds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - amountOut / 1e12, 1);
    }

    function test_previewSwapExactOut_usdcToSUsds() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 1e18 - 1), 1.25e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 1e18),     1.25e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 1e18 + 1), 1.25e6 + 1);

        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 0.8e18), 1e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 1.6e18), 2e6);
        assertEq(psm.previewSwapExactOut(address(usdc), address(susds), 2.4e18), 3e6);
    }

    function testFuzz_previewSwapExactOut_usdcToSUsds(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,     1,         SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        // Using raw calculation to demo rounding
        uint256 expectedAmountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 amountIn = psm.previewSwapExactOut(address(usdc), address(susds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_demoRoundingUp_usdcToSUsds() public view {
        uint256 expectedAmountIn1 = psm.previewSwapExactOut(address(usdc), address(susds), 0.8e18);
        uint256 expectedAmountIn2 = psm.previewSwapExactOut(address(usdc), address(susds), 0.8e18 + 1);
        uint256 expectedAmountIn3 = psm.previewSwapExactOut(address(usdc), address(susds), 0.8e18 + 0.8e12);
        uint256 expectedAmountIn4 = psm.previewSwapExactOut(address(usdc), address(susds), 0.8e18 + 0.8e12 + 1);

        assertEq(expectedAmountIn1, 1e6);
        assertEq(expectedAmountIn2, 1e6 + 1);
        assertEq(expectedAmountIn3, 1e6 + 1);
        assertEq(expectedAmountIn4, 1e6 + 2);
    }

    function test_demoRoundingUp_usdcToUsds() public view {
        uint256 expectedAmountIn1 = psm.previewSwapExactOut(address(usdc), address(usds), 1e18);
        uint256 expectedAmountIn2 = psm.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1);
        uint256 expectedAmountIn3 = psm.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1e12);
        uint256 expectedAmountIn4 = psm.previewSwapExactOut(address(usdc), address(usds), 1e18 + 1e12 + 1);

        assertEq(expectedAmountIn1, 1e6);
        assertEq(expectedAmountIn2, 1e6 + 1);
        assertEq(expectedAmountIn3, 1e6 + 1);
        assertEq(expectedAmountIn4, 1e6 + 2);
    }

}

contract PSMPreviewSwapExactIn_SUsdsAssetInTests is PSMTestBase {

    function test_previewSwapExactIn_susdsToUsds() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 1e18 - 1), 1.25e18 - 2);
        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 1e18),     1.25e18);
        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 1e18 + 1), 1.25e18 + 1);

        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 1e18), 1.25e18);
        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 2e18), 2.5e18);
        assertEq(psm.previewSwapExactIn(address(susds), address(usds), 3e18), 3.75e18);
    }

    function testFuzz_previewSwapExactIn_susdsToUsds(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        assertEq(psm.previewSwapExactIn(address(susds), address(usds), amountIn), amountOut);
    }

    function test_previewSwapExactIn_susdsToUsdc() public view {
        // Demo rounding down
        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 1e18 - 1), 1.25e6 - 1);
        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 1e18),     1.25e6);
        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 1e18 + 1), 1.25e6);

        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 1e18), 1.25e6);
        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 2e18), 2.5e6);
        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), 3e18), 3.75e6);
    }

    function testFuzz_previewSwapExactIn_susdsToUsdc(uint256 amountIn, uint256 conversionRate) public {
        amountIn       = _bound(amountIn,       1,         SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        assertEq(psm.previewSwapExactIn(address(susds), address(usdc), amountIn), amountOut);
    }

}

contract PSMPreviewSwapExactOut_SUsdsAssetInTests is PSMTestBase {

    function test_previewSwapExactOut_susdsToUsds() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 1e18 - 1), 0.8e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 1e18),     0.8e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 1e18 + 1), 0.8e18 + 1);

        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 1.25e18), 1e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 2.5e18),  2e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usds), 3.75e18), 3e18);
    }

    function testFuzz_previewSwapExactOut_susdsToUsds(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = _bound(amountOut,      1,         USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate;

        uint256 amountIn = psm.previewSwapExactOut(address(susds), address(usds), amountOut);

        // Allow for rounding error of 1 unit upwards
        assertLe(amountIn - expectedAmountIn, 1);
    }

    function test_previewSwapExactOut_susdsToUsdc() public view {
        // Demo rounding up
        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 1e6 - 1), 0.8e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 1e6),     0.8e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 1e6 + 1), 0.800001e18);

        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 1.25e6), 1e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 2.5e6),  2e18);
        assertEq(psm.previewSwapExactOut(address(susds), address(usdc), 3.75e6), 3e18);
    }

    function testFuzz_previewSwapExactOut_susdsToUsdc(uint256 amountOut, uint256 conversionRate) public {
        amountOut      = bound(amountOut,      1,         USDC_TOKEN_MAX);
        conversionRate = bound(conversionRate, 0.0001e27, 1000e27);  // 0.01% to 100,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 expectedAmountIn = amountOut * 1e27 / conversionRate * 1e12;

        uint256 amountIn = psm.previewSwapExactOut(address(susds), address(usdc), amountOut);

        // Allow for rounding error of 1e12 upwards
        assertLe(amountIn - expectedAmountIn, 1e12);
    }

}
