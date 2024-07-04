// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockERC20, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSwapExactOutFailureTests is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Needed for boundary success conditions
        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swapExactOut_amountZero() public {
        vm.expectRevert("PSM3/invalid-amountOut");
        psm.swapExactOut(address(usdc), address(sDai), 0, 0, receiver, 0);
    }

    function test_swapExactOut_receiverZero() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.swapExactOut(address(usdc), address(sDai), 100e6, 80e18, address(0), 0);
    }

    function test_swapExactOut_invalid_assetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(makeAddr("other-token"), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_invalid_assetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(dai), address(dai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(sDai), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_maxAmountBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountIn = psm.previewSwapExactOut(address(usdc), address(sDai), 80e18);

        assertEq(expectedAmountIn, 100e6);

        vm.expectRevert("PSM3/amountIn-too-high");
        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6 - 1, receiver, 0);

        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6, receiver, 0);

        usdc.approve(address(psm), 100e6);

        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6, receiver, 0);

        usdc.mint(swapper, 1);

        psm.swapExactOut(address(usdc), address(sDai), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientPsmBalanceBoundary() public {
        // NOTE: Users can get up to 1e12 more sDAI from the swap because of rounding
        // TODO: Figure out how to make this round down always
        usdc.mint(swapper, 125e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6);

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapExactOut(address(usdc), address(sDai), 100e18 + 1, 125e6, receiver, 0);

        psm.swapExactOut(address(usdc), address(sDai), 100e18, 125e6, receiver, 0);
    }

}

contract PSMSwapExactOutSuccessTestsBase is PSMTestBase {

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

    function _swapExactOutTest(
        MockERC20 assetIn,
        MockERC20 assetOut,
        uint256 amountOut,
        uint256 amountIn,
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

        psm.swapExactOut(address(assetIn), address(assetOut), amountOut, amountIn, receiver_, 0);

        assertEq(assetIn.allowance(swapper_, address(psm)), 0);

        assertEq(assetIn.balanceOf(swapper_),     0);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),    amountOut);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapExactOutDaiAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_daiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(dai, usdc, 100e6, 100e18, swapper, swapper);
    }

    function test_swapExactOut_daiToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(dai, sDai, 80e18, 100e18, swapper, swapper);
    }

    function test_swapExactOut_daiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(dai, usdc, 100e6, 100e18, swapper, receiver);
    }

    function test_swapExactOut_daiToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(dai, sDai, 80e18, 100e18, swapper, receiver);
    }

    function testFuzz_swapExactOut_daiToUsdc(
        uint256 amountOut,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut = _bound(amountOut, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountIn = amountOut * 1e12;
        _swapExactOutTest(dai, usdc, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactOut_daiToSDai(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate
        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * conversionRate / 1e27;

        _swapExactOutTest(dai, sDai, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactOutUsdcAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_usdcToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, dai, 100e18, 100e6, swapper, swapper);
    }

    function test_swapExactOut_usdcToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, sDai, 80e18, 100e6, swapper, swapper);
    }

    function test_swapExactOut_usdcToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, dai, 100e18, 100e6, swapper, receiver);
    }

    function test_swapExactOut_usdcToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, sDai, 80e18, 100e6, swapper, receiver);
    }

    function testFuzz_swapExactOut_usdcToDai(
        uint256 amountOut,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut = _bound(amountOut, 1, DAI_TOKEN_MAX);  // Zero amount reverts
        uint256 amountIn = amountOut / 1e12;
        _swapExactOutTest(usdc, dai, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactOut_usdcToSDai(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * conversionRate / 1e27 / 1e12;

        _swapExactOutTest(usdc, sDai, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactOutSDaiAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_sDaiToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(sDai, dai, 125e18, 100e18, swapper, swapper);
    }

    function test_swapExactOut_sDaiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(sDai, usdc, 125e6, 100e18, swapper, swapper);
    }

    function test_swapExactOut_sDaiToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(sDai, dai, 125e18, 100e18, swapper, receiver);
    }

    function test_swapExactOut_sDaiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(sDai, usdc, 125e6, 100e18, swapper, receiver);
    }

    function testFuzz_swapExactOut_sDaiToDai(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       DAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate;

        _swapExactOutTest(sDai, dai, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactOut_sDaiToUsdc(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate * 1e12;

        _swapExactOutTest(sDai, usdc, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

}
