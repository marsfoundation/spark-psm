// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockERC20, MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSwapFailureTests is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Needed for boundary success conditions
        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swap_amountZero() public {
        vm.expectRevert("PSM3/invalid-amountIn");
        psm.swap(address(usdc), address(sDai), 0, 0, receiver, 0);
    }

    function test_swap_receiverZero() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, address(0), 0);
    }

    function test_swap_invalid_assetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swap(makeAddr("other-token"), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_invalid_assetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swap(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swap(address(dai), address(dai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swap(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swap_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swap(address(sDai), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_minAmountOutBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountOut = psm.previewSwap(address(usdc), address(sDai), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("PSM3/amountOut-too-low");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18 + 1, receiver, 0);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);

        usdc.approve(address(psm), 100e6);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);

        usdc.mint(swapper, 1);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swap_insufficientPsmBalanceBoundary() public {
        // NOTE: Using 2 instead of 1 here because 1/1.25 rounds to 0, 2/1.25 rounds to 1
        //       this is because the conversion rate is divided out before the precision conversion
        //       is done.
        usdc.mint(swapper, 125e6 + 2);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6 + 2);

        uint256 expectedAmountOut = psm.previewSwap(address(usdc), address(sDai), 125e6 + 2);

        assertEq(expectedAmountOut, 100.000001e18);  // More than balance of sDAI

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swap(address(usdc), address(sDai), 125e6 + 2, 100e18, receiver, 0);

        psm.swap(address(usdc), address(sDai), 125e6, 100e18, receiver, 0);
    }

}

contract PSMSwapSuccessTestsBase is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Mint 100x higher than max amount for each token (max conversion rate)
        // Covers both lower and upper bounds of conversion rate (1% to 10,000% are both 100x)
        dai.mint(address(psm),  DAI_TOKEN_MAX  * 100);
        usdc.mint(address(psm), USDC_TOKEN_MAX * 100);
        sDai.mint(address(psm), SDAI_TOKEN_MAX * 100);
    }

    function _swapTest(
        MockERC20 assetIn,
        MockERC20 assetOut,
        uint256 amountIn,
        uint256 amountOut,
        address swapper_,
        address receiver_
    ) internal {
        // 100 trillion of each token corresponds to original mint amount
        uint256 psmAssetInBalance  = 100_000_000_000_000 * 10 ** assetIn.decimals();
        uint256 psmAssetOutBalance = 100_000_000_000_000 * 10 ** assetOut.decimals();

        assetIn.mint(swapper_, amountIn);

        vm.startPrank(swapper_);

        assetIn.approve(address(psm), amountIn);

        assertEq(assetIn.allowance(swapper_, address(psm)), amountIn);

        assertEq(assetIn.balanceOf(swapper_),     amountIn);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance);

        assertEq(assetOut.balanceOf(receiver_),    0);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance);

        psm.swap(address(assetIn), address(assetOut), amountIn, amountOut, receiver_, 0);

        assertEq(assetIn.allowance(swapper_, address(psm)), 0);

        assertEq(assetIn.balanceOf(swapper_),     0);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),    amountOut);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapDaiAssetInTests is PSMSwapSuccessTestsBase {

    function test_swap_daiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, usdc, 100e18, 100e6, swapper, swapper);
    }

    function test_swap_daiToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, sDai, 100e18, 80e18, swapper, swapper);
    }

    function test_swap_daiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, usdc, 100e18, 100e6, swapper, receiver);
    }

    function test_swap_daiToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, sDai, 100e18, 80e18, swapper, receiver);
    }

    function testFuzz_swap_daiToUsdc(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, DAI_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn / 1e12;
        _swapTest(dai, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swap_daiToSDai(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate
        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        _swapTest(dai, sDai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapUsdcAssetInTests is PSMSwapSuccessTestsBase {

    function test_swap_usdcToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, dai, 100e6, 100e18, swapper, swapper);
    }

    function test_swap_usdcToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, sDai, 100e6, 80e18, swapper, swapper);
    }

    function test_swap_usdcToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, dai, 100e6, 100e18, swapper, receiver);
    }

    function test_swap_usdcToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, sDai, 100e6, 80e18, swapper, receiver);
    }

    function testFuzz_swap_usdcToDai(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn * 1e12;
        _swapTest(usdc, dai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swap_usdcToSDai(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        _swapTest(usdc, sDai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapSDaiAssetInTests is PSMSwapSuccessTestsBase {

    function test_swap_sDaiToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, dai, 100e18, 125e18, swapper, swapper);
    }

    function test_swap_sDaiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, usdc, 100e18, 125e6, swapper, swapper);
    }

    function test_swap_sDaiToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, dai, 100e18, 125e18, swapper, receiver);
    }

    function test_swap_sDaiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, usdc, 100e18, 125e6, swapper, receiver);
    }

    function testFuzz_swap_sDaiToDai(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        _swapTest(sDai, dai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swap_sDaiToUsdc(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        _swapTest(sDai, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}
