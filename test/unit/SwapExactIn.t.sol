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
        usdc.mint(pocket, 100e6);
        susds.mint(address(psm), 100e18);
    }

    function test_swapExactIn_amountZero() public {
        vm.expectRevert("PSM3/invalid-amountIn");
        psm.swapExactIn(address(usdc), address(susds), 0, 0, receiver, 0);
    }

    function test_swapExactIn_receiverZero() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, address(0), 0);
    }

    function test_swapExactIn_invalid_assetIn() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(makeAddr("other-token"), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_invalid_assetOut() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothUsdc() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(usdc), address(usdc), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(usds), address(usds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_bothSUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.swapExactIn(address(susds), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_minAmountOutBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountOut = psm.previewSwapExactIn(address(usdc), address(susds), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("PSM3/amountOut-too-low");
        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18 + 1, receiver, 0);

        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, receiver, 0);

        usdc.approve(address(psm), 100e6);

        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, receiver, 0);

        usdc.mint(swapper, 1);

        psm.swapExactIn(address(usdc), address(susds), 100e6, 80e18, receiver, 0);
    }

    function test_swapExactIn_insufficientPsmBalanceBoundary() public {
        // NOTE: Using 2 instead of 1 here because 1/1.25 rounds to 0, 2/1.25 rounds to 1
        //       this is because the conversion rate is divided out before the precision conversion
        //       is done.
        usdc.mint(swapper, 125e6 + 2);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6 + 2);

        uint256 expectedAmountOut = psm.previewSwapExactIn(address(usdc), address(susds), 125e6 + 2);

        assertEq(expectedAmountOut, 100.000001e18);  // More than balance of sUSDS

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapExactIn(address(usdc), address(susds), 125e6 + 2, 100e18, receiver, 0);

        psm.swapExactIn(address(usdc), address(susds), 125e6, 100e18, receiver, 0);
    }

}

contract PSMSwapExactInSuccessTestsBase is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Mint 100x higher than max amount for each token (max conversion rate)
        // Covers both lower and upper bounds of conversion rate (1% to 10,000% are both 100x)
        usds.mint(address(psm),  USDS_TOKEN_MAX  * 100);
        usdc.mint(pocket,        USDC_TOKEN_MAX  * 100);
        susds.mint(address(psm), SUSDS_TOKEN_MAX * 100);
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

        address assetInCustodian  = address(assetIn)  == address(usdc) ? pocket : address(psm);
        address assetOutCustodian = address(assetOut) == address(usdc) ? pocket : address(psm);

        assetIn.mint(swapper_, amountIn);

        vm.startPrank(swapper_);

        assetIn.approve(address(psm), amountIn);

        assertEq(assetIn.allowance(swapper_, address(psm)), amountIn);

        assertEq(assetIn.balanceOf(swapper_),         amountIn);
        assertEq(assetIn.balanceOf(assetInCustodian), psmAssetInBalance);

        assertEq(assetOut.balanceOf(receiver_),         0);
        assertEq(assetOut.balanceOf(assetOutCustodian), psmAssetOutBalance);

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

        assertEq(assetIn.balanceOf(swapper_),         0);
        assertEq(assetIn.balanceOf(assetInCustodian), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver_),         amountOut);
        assertEq(assetOut.balanceOf(assetOutCustodian), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapExactInUsdsAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_usdsToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usds, usdc, 100e18, 100e6, swapper, swapper);
    }

    function test_swapExactIn_usdsToSUsds_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usds, susds, 100e18, 80e18, swapper, swapper);
    }

    function test_swapExactIn_usdsToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usds, usdc, 100e18, 100e6, swapper, receiver);
    }

    function test_swapExactIn_usdsToSUsds_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usds, susds, 100e18, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_usdsToUsdc(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, USDS_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn / 1e12;
        _swapExactInTest(usds, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_usdsToSUsds(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       USDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate
        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate;

        _swapExactInTest(usds, susds, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInUsdcAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_usdcToUsds_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, usds, 100e6, 100e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToSUsds_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, susds, 100e6, 80e18, swapper, swapper);
    }

    function test_swapExactIn_usdcToUsds_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, usds, 100e6, 100e18, swapper, receiver);
    }

    function test_swapExactIn_usdcToSUsds_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(usdc, susds, 100e6, 80e18, swapper, receiver);
    }

    function testFuzz_swapExactIn_usdcToUsds(
        uint256 amountIn,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn = _bound(amountIn, 1, USDC_TOKEN_MAX);  // Zero amount reverts
        uint256 amountOut = amountIn * 1e12;
        _swapExactInTest(usdc, usds, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_usdcToSUsds(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       USDC_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * 1e27 / conversionRate * 1e12;

        _swapExactInTest(usdc, susds, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInSUsdsAssetInTests is PSMSwapExactInSuccessTestsBase {

    function test_swapExactIn_susdsToUsds_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(susds, usds, 100e18, 125e18, swapper, swapper);
    }

    function test_swapExactIn_susdsToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(susds, usdc, 100e18, 125e6, swapper, swapper);
    }

    function test_swapExactIn_susdsToUsds_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(susds, usds, 100e18, 125e18, swapper, receiver);
    }

    function test_swapExactIn_susdsToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapExactInTest(susds, usdc, 100e18, 125e6, swapper, receiver);
    }

    function testFuzz_swapExactIn_susdsToUsds(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27;

        _swapExactInTest(susds, usds, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

    function testFuzz_swapExactIn_susdsToUsdc(
        uint256 amountIn,
        uint256 conversionRate,
        address fuzzSwapper,
        address fuzzReceiver
    ) public {
        vm.assume(fuzzSwapper  != address(psm));
        vm.assume(fuzzSwapper  != address(pocket));
        vm.assume(fuzzReceiver != address(psm));
        vm.assume(fuzzReceiver != address(pocket));
        vm.assume(fuzzReceiver != address(0));

        amountIn       = _bound(amountIn,       1,       SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 100e27);  // 1% to 10,000% conversion rate

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 amountOut = amountIn * conversionRate / 1e27 / 1e12;

        _swapExactInTest(susds, usdc, amountIn, amountOut, fuzzSwapper, fuzzReceiver);
    }

}

contract PSMSwapExactInFuzzTests is PSMTestBase {

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
    /// forge-config: master.fuzz.runs = 1000
    function testFuzz_swapExactIn(
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

        for (uint256 i; i < 1000; ++i) {
            MockERC20 assetIn  = _getAsset(_hash(i, "assetIn"));
            MockERC20 assetOut = _getAsset(_hash(i, "assetOut"));

            if (assetIn == assetOut) {
                assetOut = _getAsset(_hash(i, "assetOut") + 1);
            }

            address assetOutCustodian = address(assetOut) == address(usdc) ? pocket : address(psm);

            // Calculate the maximum amount that can be swapped by using the inverse conversion rate
            uint256 maxAmountIn = psm.previewSwapExactOut(
                address(assetIn),
                address(assetOut),
                assetOut.balanceOf(assetOutCustodian)
            );

            uint256 amountIn = _bound(_hash(i, "amountIn"), 0, maxAmountIn - 1);  // Rounding

            vars.lp0CachedValue = psm.convertToAssetValue(psm.shares(lp0));
            vars.lp1CachedValue = psm.convertToAssetValue(psm.shares(lp1));
            vars.lp2CachedValue = psm.convertToAssetValue(psm.shares(lp2));
            vars.psmCachedValue = psm.totalAssets();

            assetIn.mint(swapper, amountIn);
            assetIn.approve(address(psm), amountIn);
            psm.swapExactIn(address(assetIn), address(assetOut), amountIn, 0, swapper, 0);

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
