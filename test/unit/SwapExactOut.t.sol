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
        susds.mint(address(psm), 100e18);
    }

    function test_swapExactOut_amountZero() public {
        vm.expectRevert("PSM3/invalid-amountOut");
        psm.swapExactOut(address(usdc), address(susds), 0, 0, receiver, 0);
    }

    function test_swapExactOut_receiverZero() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.swapExactOut(address(usdc), address(susds), 100e6, 80e18, address(0), 0);
    }

    function test_swapExactOut_invalid_assetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(makeAddr("other-token"), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_invalid_assetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothUsdc() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(usds), address(usds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_bothSUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactOut(address(susds), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactOut_maxAmountBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountIn = psm.previewSwapExactOut(address(usdc), address(susds), 80e18);

        assertEq(expectedAmountIn, 100e6);

        vm.expectRevert("PSM3/amountIn-too-high");
        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6 - 1, receiver, 0);

        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6, receiver, 0);

        usdc.approve(address(psm), 100e6);

        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6, receiver, 0);

        usdc.mint(swapper, 1);

        psm.swapExactOut(address(usdc), address(susds), 80e18, 100e6, receiver, 0);
    }

    function test_swapExactOut_insufficientPsmBalanceBoundary() public {
        // NOTE: Using higher amount so transfer fails
        usdc.mint(swapper, 125e6 + 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6 + 1);

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapExactOut(address(usdc), address(susds), 100e18 + 1, 125e6 + 1, receiver, 0);

        psm.swapExactOut(address(usdc), address(susds), 100e18, 125e6 + 1, receiver, 0);
    }

}

contract PSMSwapExactOutSuccessTestsBase is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Mint 100x higher than max amount for each token (max conversion rate)
        // Covers both lower and upper bounds of conversion rate (1% to 10,000% are both 100x)
        usds.mint(address(psm),  USDS_TOKEN_MAX  * 100);
        usdc.mint(address(psm),  USDC_TOKEN_MAX  * 100);
        susds.mint(address(psm), SUSDS_TOKEN_MAX * 100);
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

        uint256 returnedAmountIn = psm.swapExactOut(
            address(assetIn),
            address(assetOut),
            amountOut,
            amountIn,
            receiver_,
            0
        );

        assertEq(returnedAmountIn, amountIn);

        assertEq(assetIn.allowance(swapper_, address(psm)), 0);

        assertEq(assetIn.balanceOf(swapper_),     0);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),    amountOut);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapExactOutDaiAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_usdsToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usds, usdc, 100e6, 100e18, swapper, swapper);
    }

    function test_swapExactOut_usdsToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usds, susds, 80e18, 100e18, swapper, swapper);
    }

    function test_swapExactOut_usdsToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usds, usdc, 100e6, 100e18, swapper, receiver);
    }

    function test_swapExactOut_usdsToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usds, susds, 80e18, 100e18, swapper, receiver);
    }

    function testFuzz_swapExactOut_usdsToUsdc(
        uint256 amountOut,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut = _bound(amountOut, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountIn = amountOut * 1e12;
        _swapExactOutTest(usds, usdc, amountOut, amountIn, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactOut_usdsToSDai(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate
        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * conversionRate / 1e27;

        uint256 returnedAmountIn = psm.previewSwapExactOut(address(usds), address(susds), amountOut);

        // Assert that returnedAmount is within 1 of the expected amount and rounding up
        // Use returnedAmountIn in helper function so all values are exact
        assertLe(returnedAmountIn - amountIn, 1);

        _swapExactOutTest(usds, susds, amountOut, returnedAmountIn, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactOutUsdcAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_usdcToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, usds, 100e18, 100e6, swapper, swapper);
    }

    function test_swapExactOut_usdcToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, susds, 80e18, 100e6, swapper, swapper);
    }

    function test_swapExactOut_usdcToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, usds, 100e18, 100e6, swapper, receiver);
    }

    function test_swapExactOut_usdcToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(usdc, susds, 80e18, 100e6, swapper, receiver);
    }

    function testFuzz_swapExactOut_usdcToDai(
        uint256 amountOut,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut = _bound(amountOut, 1, USDS_TOKEN_MAX);  // Zero amount reverts
        uint256 amountIn = amountOut / 1e12;

        uint256 returnedAmountIn = psm.previewSwapExactOut(address(usdc), address(usds), amountOut);

        // Assert that returnedAmount is within 1 of the expected amount and rounding up
        // Use returnedAmountIn in helper function so all values are exact
        assertLe(returnedAmountIn - amountIn, 1);

        _swapExactOutTest(usdc, usds, amountOut, returnedAmountIn, fuzzSwapper, fuzzReceiver);
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

        amountOut      = _bound(amountOut,      1,       SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * conversionRate / 1e27 / 1e12;

        uint256 returnedAmountIn = psm.previewSwapExactOut(address(usdc), address(susds), amountOut);

        // Assert that returnedAmount is within 1 of the expected amount and rounding up
        // Use returnedAmountIn in helper function so all values are exact
        assertLe(returnedAmountIn - amountIn, 1);

        _swapExactOutTest(usdc, susds, amountOut, returnedAmountIn, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactOutSDaiAssetInTests is PSMSwapExactOutSuccessTestsBase {

    function test_swapExactOut_susdsToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(susds, usds, 125e18, 100e18, swapper, swapper);
    }

    function test_swapExactOut_susdsToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(susds, usdc, 125e6, 100e18, swapper, swapper);
    }

    function test_swapExactOut_susdsToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(susds, usds, 125e18, 100e18, swapper, receiver);
    }

    function test_swapExactOut_susdsToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactOutTest(susds, usdc, 125e6, 100e18, swapper, receiver);
    }

    function testFuzz_swapExactOut_susdsToDai(
        uint256 amountOut,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(0));

        amountOut      = _bound(amountOut,      1,       USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate;

        uint256 returnedAmountIn = psm.previewSwapExactOut(address(susds), address(usds), amountOut);

        // Assert that returnedAmount is within 1 of the expected amount and rounding up
        // Use returnedAmountIn in helper function so all values are exact
        assertLe(returnedAmountIn - amountIn, 1);

        _swapExactOutTest(susds, usds, amountOut, returnedAmountIn, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactOut_susdsToUsdc(
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

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountIn = amountOut * 1e27 / conversionRate * 1e12;

        uint256 returnedAmountIn = psm.previewSwapExactOut(address(susds), address(usdc), amountOut);

        // Assert that returnedAmount is within 1 of the expected amount and rounding up
        // Use returnedAmountIn in helper function so all asserted values are exact
        // Rounding can cause returnedAmountIn to be up to 1e12 higher than naive calculation
        assertLe(returnedAmountIn - amountIn, 1e12);

        _swapExactOutTest(susds, usdc, amountOut, returnedAmountIn, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactOutFuzzTests is PSMTestBase {

    address lp0 = makeAddr("lp0");
    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");

    address swapper = makeAddr("swapper");

    struct FuzzVars {
        uint256 lp0StartingValue;
        uint256 lp1StartingValue;
        uint256 lp2StartingValue;
        uint256 psmStartingValue;
        uint256 lp0CachedValue;
        uint256 lp1CachedValue;
        uint256 lp2CachedValue;
        uint256 psmCachedValue;
    }

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: pr.fuzz.runs = 100
    /// forge-config: master.fuzz.runs = 10000
    function testFuzz_swapExactOut(
        uint256 conversionRate,
        uint256 depositSeed
    ) public {
        // 1% to 200% conversion rate
        mockRateProvider.__setConversionRate(_bound(conversionRate, 0.01e27, 2e27));

        _deposit(address(usds), lp0, _bound(_hash(depositSeed, "lp0-usds"), 1, USDS_TOKEN_MAX));

        _deposit(address(usdc),  lp1, _bound(_hash(depositSeed, "lp1-usdc"),  1, USDC_TOKEN_MAX));
        _deposit(address(susds), lp1, _bound(_hash(depositSeed, "lp1-susds"), 1, SUSDS_TOKEN_MAX));

        _deposit(address(usds),  lp2, _bound(_hash(depositSeed, "lp2-usds"),  1, USDS_TOKEN_MAX));
        _deposit(address(usdc),  lp2, _bound(_hash(depositSeed, "lp2-usdc"),  1, USDC_TOKEN_MAX));
        _deposit(address(susds), lp2, _bound(_hash(depositSeed, "lp2-susds"), 1, SUSDS_TOKEN_MAX));

        FuzzVars memory vars;

        vars.lp0StartingValue = psm.convertToAssetValue(psm.shares(lp0));
        vars.lp1StartingValue = psm.convertToAssetValue(psm.shares(lp1));
        vars.lp2StartingValue = psm.convertToAssetValue(psm.shares(lp2));
        vars.psmStartingValue = psm.totalAssets();

        vm.startPrank(swapper);

        for (uint256 i; i < 10; ++i) {
            MockERC20 assetIn  = _getAsset(_hash(i, "assetIn"));
            MockERC20 assetOut = _getAsset(_hash(i, "assetOut"));

            if (assetIn == assetOut) {
                assetOut = _getAsset(_hash(i, "assetOut") + 1);
            }

            uint256 amountOut = _bound(_hash(i, "amountOut"), 0, assetOut.balanceOf(address(psm)));

            uint256 amountIn
                = psm.previewSwapExactOut(address(assetIn), address(assetOut), amountOut);

            vars.lp0CachedValue = psm.convertToAssetValue(psm.shares(lp0));
            vars.lp1CachedValue = psm.convertToAssetValue(psm.shares(lp1));
            vars.lp2CachedValue = psm.convertToAssetValue(psm.shares(lp2));
            vars.psmCachedValue = psm.totalAssets();

            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(psm), amountIn);
            psm.swapExactOut(address(assetIn), address(assetOut), amountOut, amountIn, swapper, 0);

            // Rounding is always in favour of the LPs
            assertGe(psm.convertToAssetValue(psm.shares(lp0)), vars.lp0CachedValue);
            assertGe(psm.convertToAssetValue(psm.shares(lp1)), vars.lp1CachedValue);
            assertGe(psm.convertToAssetValue(psm.shares(lp2)), vars.lp2CachedValue);
            assertGe(psm.totalAssets(),                        vars.psmCachedValue);

            // Up to 2e12 rounding on each swap
            assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp0)), vars.lp0CachedValue, 2e12);
            assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp1)), vars.lp1CachedValue, 2e12);
            assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp2)), vars.lp2CachedValue, 2e12);
            assertApproxEqAbs(psm.totalAssets(),                        vars.psmCachedValue, 2e12);
        }

        // Rounding is always in favour of the LPs
        assertGe(psm.convertToAssetValue(psm.shares(lp0)), vars.lp0StartingValue);
        assertGe(psm.convertToAssetValue(psm.shares(lp1)), vars.lp1StartingValue);
        assertGe(psm.convertToAssetValue(psm.shares(lp2)), vars.lp2StartingValue);
        assertGe(psm.totalAssets(),                        vars.psmStartingValue);

        // Up to 2e12 rounding on each swap, for 1000 swaps
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp0)), vars.lp0StartingValue, 2000e12);
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp1)), vars.lp1StartingValue, 2000e12);
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(lp2)), vars.lp2StartingValue, 2000e12);
        assertApproxEqAbs(psm.totalAssets(),                        vars.psmStartingValue, 2000e12);
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        uint256 index = indexSeed % 3;

        if (index == 0) return usds;
        if (index == 1) return usdc;
        if (index == 2) return susds;

        else revert("Invalid index");
    }

}
