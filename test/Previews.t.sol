// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewSwapFailureTests is PSMTestBase {

    function test_previewSwap_invalidAssetIn() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.previewSwap(makeAddr("other-token"), address(usdc), 1);
    }

    function test_previewSwap_invalidAssetOut() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.previewSwap(address(usdc), makeAddr("other-token"), 1);
    }

}

// TODO: Determine if 10 billion is too low of an upper bound for sDAI swaps,
//       if exchange rate lower bound should be raised (applies to swap tests too).

contract PSMPreviewSwapDaiAssetInTests is PSMTestBase {

    function test_previewSwap_daiToUsdc() public view {
        assertEq(psm.previewSwap(address(dai), address(usdc), 1e12 - 1), 0);
        assertEq(psm.previewSwap(address(dai), address(usdc), 1e12),     1);

        assertEq(psm.previewSwap(address(dai), address(usdc), 1e18), 1e6);
    }

    function testFuzz_previewSwap_daiToUsdc(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, DAI_TOKEN_MAX);

        assertEq(psm.previewSwap(address(dai), address(usdc), amountIn), amountIn / 1e12);
    }

    function test_previewSwap_daiToSDai() public view {
        assertEq(psm.previewSwap(address(dai), address(sDai), 1e18), 0.8e18);
    }

    function testFuzz_previewSwap_daiToSDai(uint256 amountIn, uint256 exchangeRate) public {
        amountIn     = _bound(amountIn,     1,       10_000_000_000e18);  // Using 10 billion for conversion rates
        exchangeRate = _bound(exchangeRate, 0.01e27, 1000e27);             // 1% to 100,000% conversion rate

        rateProvider.__setConversionRate(exchangeRate);

        uint256 amountOut = amountIn * 1e27 / exchangeRate;

        assertEq(psm.previewSwap(address(dai), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapUSDCAssetInTests is PSMTestBase {

    function test_previewSwap_usdcToDai() public view {
        assertEq(psm.previewSwap(address(usdc), address(dai), 1e6),  1e18);
    }

    function testFuzz_previewSwap_usdcToDai(uint256 amountIn) public view {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        assertEq(psm.previewSwap(address(usdc), address(dai), amountIn), amountIn * 1e12);
    }

    function test_previewSwap_usdcToSDai() public view {
        assertEq(psm.previewSwap(address(usdc), address(sDai), 1e6), 0.8e18);
    }

    function testFuzz_previewSwap_daiToSDai(uint256 amountIn, uint256 exchangeRate) public {
        amountIn = _bound(amountIn, 0, USDC_TOKEN_MAX);

        amountIn     = _bound(amountIn,     1,       10_000_000_000e18);  // Using 10 billion for conversion rates
        exchangeRate = _bound(exchangeRate, 0.01e27, 1000e27);             // 1% to 100,000% conversion rate

        rateProvider.__setConversionRate(exchangeRate);

        uint256 amountOut = amountIn * 1e27 * 1e12 / exchangeRate;

        assertEq(psm.previewSwap(address(usdc), address(sDai), amountIn), amountOut);
    }

}

contract PSMPreviewSwapSDaiAssetInTests is PSMTestBase {

    function test_previewSwap_sDaiToDai() public view {
        assertEq(psm.previewSwap(address(sDai), address(dai), 1e18),  1.25e18);
    }

    function testFuzz_previewSwap_sDaiToDai(uint256 amountIn, uint256 exchangeRate) public {
        amountIn     = _bound(amountIn,     1,       10_000_000_000e6);  // Using 10 billion for conversion rates
        exchangeRate = _bound(exchangeRate, 0.01e27, 1000e27);           // 1% to 100,000% conversion rate

        rateProvider.__setConversionRate(exchangeRate);

        uint256 amountOut = amountIn * exchangeRate / 1e27;

        assertEq(psm.previewSwap(address(sDai), address(dai), amountIn), amountOut);
    }

    function test_previewSwap_sDaiToUsdc() public view {
        assertEq(psm.previewSwap(address(sDai), address(usdc), 1e18), 1.25e6);
    }

    function testFuzz_previewSwap_sDaiToUsdc(uint256 amountIn, uint256 exchangeRate) public {
        amountIn     = _bound(amountIn,     1,       10_000_000_000e18);  // Using 10 billion for conversion rates
        exchangeRate = _bound(exchangeRate, 0.01e27, 1000e27);             // 1% to 100,000% conversion rate

        rateProvider.__setConversionRate(exchangeRate);

        uint256 amountOut = amountIn * exchangeRate / 1e27 / 1e12;

        assertEq(psm.previewSwap(address(sDai), address(usdc), amountIn), amountOut);
    }

}

