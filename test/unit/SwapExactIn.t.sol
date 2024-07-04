// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockERC20, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSwapExactInFailureTests is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Needed for boundary success conditions
        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swapExactIn_amountZero() public {
        vm.expectRevert("PSM3/invalid-amountIn");
        psm.swapExactIn(address(usdc), address(sDai), 0, 0, receiver, 0);
    }

    function test_swapExactIn_receiverZero() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, address(0), 0);
    }

    function test_swapExactIn_invalid_assetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(makeAddr("other-token"), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_invalid_assetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothAsset0() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(dai), address(dai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothAsset2() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(sDai), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_minAmountOutBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountOut = psm.previewSwapExactIn(address(usdc), address(sDai), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("PSM3/amountOut-too-low");
        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18 + 1, receiver, 0);

        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);

        usdc.approve(address(psm), 100e6);

        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);

        usdc.mint(swapper, 1);

        psm.swapExactIn(address(usdc), address(sDai), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientPsmBalanceBoundary() public {
        // NOTE: Using 2 instead of 1 here because 1/1.25 rounds to 0, 2/1.25 rounds to 1
        //       this is because the conversion rate is divided out before the precision conversion
        //       is done.
        usdc.mint(swapper, 125e6 + 2);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6 + 2);

        uint256 expectedAmountOut = psm.previewSwapExactIn(address(usdc), address(sDai), 125e6 + 2);

        assertEq(expectedAmountOut, 100.000001e18);  // More than balance of sDAI

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapExactIn(address(usdc), address(sDai), 125e6 + 2, 100e18, receiver, 0);

        psm.swapExactIn(address(usdc), address(sDai), 125e6, 100e18, receiver, 0);
    }

}

contract PSMSwapExactInSuccessTestsBase is PSMTestBase {

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

    function _swapExactInTest(
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

        uint256 returnedAmountOut = psm.swapExactIn(
            address(assetIn),
            address(assetOut),
            amountIn,
            amountOut,
            receiver_,
            0
        );

        assertEq(returnedAmountOut, amountOut);

        assertEq(assetIn.allowance(swapper_, address(psm)), 0);

        assertEq(assetIn.balanceOf(swapper_),     0);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),    amountOut);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapExactInDaiAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_daiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(dai, usdc, 100e18, 100e6, swapper, swapper);
    }

    function test_swapExactIn_daiToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(dai, sDai, 100e18, 80e18, swapper, swapper);
    }

    function test_swapExactIn_daiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(dai, usdc, 100e18, 100e6, swapper, receiver);
    }

    function test_swapExactIn_daiToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(dai, sDai, 100e18, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_daiToUsdc(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, DAI_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn / 1e12;
        _swapExactInTest(dai, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_daiToSDai(
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
        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        _swapExactInTest(dai, sDai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInUsdcAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_usdcToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, dai, 100e6, 100e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, sDai, 100e6, 80e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, dai, 100e6, 100e18, swapper, receiver);
    }

    function test_swapExactIn_usdcToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, sDai, 100e6, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_usdcToDai(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn * 1e12;
        _swapExactInTest(usdc, dai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_usdcToSDai(
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

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        _swapExactInTest(usdc, sDai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInSDaiAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_sDaiToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(sDai, dai, 100e18, 125e18, swapper, swapper);
    }

    function test_swapExactIn_sDaiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(sDai, usdc, 100e18, 125e6, swapper, swapper);
    }

    function test_swapExactIn_sDaiToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(sDai, dai, 100e18, 125e18, swapper, receiver);
    }

    function test_swapExactIn_sDaiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(sDai, usdc, 100e18, 125e6, swapper, receiver);
    }

    function testFuzz_swapExactIn_sDaiToDai(
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

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        _swapExactInTest(sDai, dai, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_sDaiToUsdc(
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

        rateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        _swapExactInTest(sDai, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInFuzzTests is PSMTestBase {

    address lp0 = makeAddr("lp0");
    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");

    address swapper = makeAddr("swapper");

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        uint256 index = indexSeed % 3;

        if (index == 0) return dai;
        if (index == 1) return usdc;
        if (index == 2) return sDai;
    }

    /// forge-config: default.fuzz.runs = 1
    function testFuzz_swapExactIn(
        uint256 conversionRate,
        uint256 depositSeed
    ) public {
        // 1. LPs deposit fuzzed amounts of all tokens
        // 2. 1000 swaps happen
        // 3. Check that the LPs have the same balances
        // 4. Check that the PSM has the same value

        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        rateProvider.__setConversionRate(conversionRate);

        _deposit(address(dai), lp0, _bound(_hash(depositSeed, "lp0-dai"), 1, DAI_TOKEN_MAX));

        _deposit(address(usdc), lp1, _bound(_hash(depositSeed, "lp1-usdc"), 1, USDC_TOKEN_MAX));
        _deposit(address(sDai), lp1, _bound(_hash(depositSeed, "lp1-sdai"), 1, SDAI_TOKEN_MAX));

        _deposit(address(dai),  lp2, _bound(_hash(depositSeed, "lp2-dai"),  1, DAI_TOKEN_MAX));
        _deposit(address(usdc), lp2, _bound(_hash(depositSeed, "lp2-usdc"), 1, USDC_TOKEN_MAX));
        _deposit(address(sDai), lp2, _bound(_hash(depositSeed, "lp2-sdai"), 1, SDAI_TOKEN_MAX));

        vm.startPrank(swapper);

        for (uint256 i; i < 1000; ++i) {
            MockERC20 assetIn  = _getAsset(_hash(i, "assetIn"));
            MockERC20 assetOut = _getAsset(_hash(i, "assetOut"));

            // Calculate the maximum amount that can be swapped by using the inverse conversion rate
            uint256 maxAmountIn = psm.previewSwapExactOut(
                address(assetOut),
                address(assetIn),
                assetOut.balanceOf(address(psm))
            );

            uint256 amountIn = _bound(_hash(i, "amountIn"), 0, maxAmountIn);

            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(psm), amountIn);
            psm.swapExactIn(address(assetIn), address(assetOut), amountIn, 0, swapper, 0);
        }

    }
}
