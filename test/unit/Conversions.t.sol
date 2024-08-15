// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConversionTestBase is PSMTestBase {

    struct FuzzVars {
        uint256 daiAmount;
        uint256 usdcAmount;
        uint256 sDaiAmount;
        uint256 expectedShares;
    }

    // Takes in fuzz inputs, bounds them, deposits assets, and returns
    // initial shares from all deposits (always equal to total value at beginning).
    function _setUpConversionFuzzTest(
        uint256 initialConversionRate,
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount
    )
        internal returns (FuzzVars memory vars)
    {
        vars.daiAmount  = _bound(daiAmount,  1, DAI_TOKEN_MAX);
        vars.usdcAmount = _bound(usdcAmount, 1, USDC_TOKEN_MAX);
        vars.sDaiAmount = _bound(sDaiAmount, 1, SDAI_TOKEN_MAX);

        _deposit(address(dai),  address(this), vars.daiAmount);
        _deposit(address(usdc), address(this), vars.usdcAmount);
        _deposit(address(sDai), address(this), vars.sDaiAmount);

        vars.expectedShares =
            vars.daiAmount +
            vars.usdcAmount * 1e12 +
            vars.sDaiAmount * initialConversionRate / 1e27;

        // Assert that shares to be used for calcs are correct
        assertEq(psm.totalShares(), vars.expectedShares);
    }
}

contract PSMConvertToAssetsTests is PSMTestBase {

    function test_convertToAssets_invalidAsset() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.convertToAssets(makeAddr("new-asset"), 100);
    }

    function test_convertToAssets() public view {
        assertEq(psm.convertToAssets(address(dai), 1), 1);
        assertEq(psm.convertToAssets(address(dai), 2), 2);
        assertEq(psm.convertToAssets(address(dai), 3), 3);

        assertEq(psm.convertToAssets(address(dai), 1e18), 1e18);
        assertEq(psm.convertToAssets(address(dai), 2e18), 2e18);
        assertEq(psm.convertToAssets(address(dai), 3e18), 3e18);

        assertEq(psm.convertToAssets(address(usdc), 1), 0);
        assertEq(psm.convertToAssets(address(usdc), 2), 0);
        assertEq(psm.convertToAssets(address(usdc), 3), 0);

        assertEq(psm.convertToAssets(address(usdc), 1e18), 1e6);
        assertEq(psm.convertToAssets(address(usdc), 2e18), 2e6);
        assertEq(psm.convertToAssets(address(usdc), 3e18), 3e6);

        assertEq(psm.convertToAssets(address(sDai), 1), 0);
        assertEq(psm.convertToAssets(address(sDai), 2), 1);
        assertEq(psm.convertToAssets(address(sDai), 3), 2);

        assertEq(psm.convertToAssets(address(sDai), 1e18), 0.8e18);
        assertEq(psm.convertToAssets(address(sDai), 2e18), 1.6e18);
        assertEq(psm.convertToAssets(address(sDai), 3e18), 2.4e18);
    }

    function testFuzz_convertToAssets_asset0(uint256 amount) public view {
        amount = _bound(amount, 0, DAI_TOKEN_MAX);

        assertEq(psm.convertToAssets(address(dai), amount), amount);
    }

    function testFuzz_convertToAssets_asset1(uint256 amount) public view {
        amount = _bound(amount, 0, USDC_TOKEN_MAX);

        assertEq(psm.convertToAssets(address(usdc), amount), amount / 1e12);
    }

    function testFuzz_convertToAssets_asset2(uint256 conversionRate, uint256 amount) public {
        // NOTE: 0.0001e27 considered lower bound for overflow considerations
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);
        amount         = _bound(amount,         0,         SDAI_TOKEN_MAX);

        mockRateProvider.__setConversionRate(conversionRate);

        assertEq(psm.convertToAssets(address(sDai), amount), amount * 1e27 / conversionRate);
    }

}

contract PSMConvertToAssetValueTests is PSMConversionTestBase {

    function testFuzz_convertToAssetValue_noValue(uint256 amount) public view {
        assertEq(psm.convertToAssetValue(amount), amount);
    }

    function test_convertToAssetValue() public {
        _deposit(address(dai),  address(this), 100e18);
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(sDai), address(this), 80e18);

        assertEq(psm.convertToAssetValue(1e18), 1e18);

        mockRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // sDAI portion becomes worth $160, full pool worth $360, each share worth $1.20
        assertEq(psm.convertToAssetValue(1e18), 1.2e18);
    }

    function testFuzz_convertToAssetValue_conversionRateIncrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToAssetValue(vars.expectedShares), initialValue);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from sDAI exchange rate increasing
        assertEq(newValue - initialValue, vars.sDaiAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToAssetValue(vars.expectedShares), initialValue);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from sDAI exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.sDaiAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

}

contract PSMConvertToSharesTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        assertEq(psm.convertToShares(amount), amount);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(usdc), address(this), 100e6);
        _assertOneToOneConversion();

        _deposit(address(sDai), address(this), 80e18);
        _assertOneToOneConversion();

        _withdraw(address(usdc), address(this), 100e6);
        _assertOneToOneConversion();

        _withdraw(address(sDai), address(this), 80e18);
        _assertOneToOneConversion();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(sDai), address(this), 80e18);

        _assertOneToOneConversion();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(10), 9);
        assertEq(psm.convertToShares(11), 10);
        assertEq(psm.convertToShares(12), 10);

        assertEq(psm.convertToShares(1e18),   0.909090909090909090e18);
        assertEq(psm.convertToShares(1.1e18), 1e18);
        assertEq(psm.convertToShares(1.2e18), 1.090909090909090909e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(newValue), vars.expectedShares);

        // Value change is only from sDAI exchange rate increasing
        assertEq(newValue - initialValue, vars.sDaiAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(newValue), vars.expectedShares);

        // Value change is only from sDAI exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.sDaiAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversion() internal view {
        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(2), 2);
        assertEq(psm.convertToShares(3), 3);
        assertEq(psm.convertToShares(4), 4);

        assertEq(psm.convertToShares(1e18), 1e18);
        assertEq(psm.convertToShares(2e18), 2e18);
        assertEq(psm.convertToShares(3e18), 3e18);
        assertEq(psm.convertToShares(4e18), 4e18);
    }

}

contract PSMConvertToSharesFailureTests is PSMTestBase {

    function test_convertToShares_invalidAsset() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.convertToShares(makeAddr("new-asset"), 100);
    }

}

contract PSMConvertToSharesWithDaiTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionDai();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, DAI_TOKEN_MAX);
        assertEq(psm.convertToShares(address(dai), amount), amount);
    }

    function test_convertToShares_depositAndWithdrawDaiAndSDai_noChange() public {
        _assertOneToOneConversionDai();

        _deposit(address(dai), address(this), 100e18);
        _assertOneToOneConversionDai();

        _deposit(address(sDai), address(this), 80e18);
        _assertOneToOneConversionDai();

        _withdraw(address(dai), address(this), 100e18);
        _assertOneToOneConversionDai();

        _withdraw(address(sDai), address(this), 80e18);
        _assertOneToOneConversionDai();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(dai),  address(this), 100e18);
        _deposit(address(sDai), address(this), 80e18);

        _assertOneToOneConversionDai();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(dai), 10), 9);
        assertEq(psm.convertToShares(address(dai), 11), 10);
        assertEq(psm.convertToShares(address(dai), 12), 10);

        assertEq(psm.convertToShares(address(dai), 10e18), 9.090909090909090909e18);
        assertEq(psm.convertToShares(address(dai), 11e18), 10e18);
        assertEq(psm.convertToShares(address(dai), 12e18), 10.909090909090909090e18);
    }

    // NOTE: These tests will be the exact same as convertToShares(amount) tests because DAI is an
    //       18 decimal precision asset pegged to the dollar, which is whats used for "value".

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(address(dai), initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(address(dai), newValue), vars.expectedShares);

        // Value change is only from sDAI exchange rate increasing
        assertEq(newValue - initialValue, vars.sDaiAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(address(dai), initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(address(dai), newValue), vars.expectedShares);

        // Value change is only from sDAI exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.sDaiAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversionDai() internal view {
        assertEq(psm.convertToShares(address(dai), 1), 1);
        assertEq(psm.convertToShares(address(dai), 2), 2);
        assertEq(psm.convertToShares(address(dai), 3), 3);
        assertEq(psm.convertToShares(address(dai), 4), 4);

        assertEq(psm.convertToShares(address(dai), 1e18), 1e18);
        assertEq(psm.convertToShares(address(dai), 2e18), 2e18);
        assertEq(psm.convertToShares(address(dai), 3e18), 3e18);
        assertEq(psm.convertToShares(address(dai), 4e18), 4e18);
    }

}

contract PSMConvertToSharesWithUsdcTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionUsdc();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, USDC_TOKEN_MAX);
        assertEq(psm.convertToShares(address(usdc), amount), amount * 1e12);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversionUsdc();

        _deposit(address(usdc), address(this), 100e6);
        _assertOneToOneConversionUsdc();

        _deposit(address(sDai), address(this), 80e18);
        _assertOneToOneConversionUsdc();

        _withdraw(address(usdc), address(this), 100e6);
        _assertOneToOneConversionUsdc();

        _withdraw(address(sDai), address(this), 80e18);
        _assertOneToOneConversionUsdc();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(sDai), address(this), 80e18);

        _assertOneToOneConversionUsdc();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(usdc), 10), 9.090909090909e12);
        assertEq(psm.convertToShares(address(usdc), 11), 10e12);
        assertEq(psm.convertToShares(address(usdc), 12), 10.909090909090e12);

        assertEq(psm.convertToShares(address(usdc), 10e6), 9.090909090909090909e18);
        assertEq(psm.convertToShares(address(usdc), 11e6), 10e18);
        assertEq(psm.convertToShares(address(usdc), 12e6), 10.909090909090909090e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // Precision is lost when using 1e6 so expectedShares have to be adjusted accordingly
        // but this represents a 1:1 exchange rate in 1e6 precision
        assertEq(
            psm.convertToShares(address(usdc), initialValue / 1e12),
            vars.expectedShares / 1e12 * 1e12
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        // Larger rounding error because of 1e6 precision
        assertApproxEqAbs(
            psm.convertToShares(address(usdc), newValue / 1e12),
            vars.expectedShares,
            1e12
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(usdc), newValue / 1e12),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(usdc), newValue / 1e12),
            (newValue / 1e12 * 1e12) * vars.expectedShares / newValue
        );

        // Value change is only from sDAI exchange rate increasing
        assertEq(newValue - initialValue, vars.sDaiAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // Precision is lost when using 1e6 so expectedShares have to be adjusted accordingly
        // but this represents a 1:1 exchange rate in 1e6 precision
        assertEq(
            psm.convertToShares(address(usdc), initialValue / 1e12),
            vars.expectedShares / 1e12 * 1e12
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        // Rounding scales with difference between expectedShares and newValue
        assertApproxEqAbs(
            psm.convertToShares(address(usdc), newValue / 1e12),
            vars.expectedShares,
            1e12 + initialValue * 1e18 / newValue
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(usdc), newValue / 1e12),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(usdc), newValue / 1e12),
            (newValue / 1e12 * 1e12) * vars.expectedShares / newValue
        );

        // Value change is only from sDAI exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.sDaiAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversionUsdc() internal view {
        assertEq(psm.convertToShares(address(usdc), 1), 1e12);
        assertEq(psm.convertToShares(address(usdc), 2), 2e12);
        assertEq(psm.convertToShares(address(usdc), 3), 3e12);
        assertEq(psm.convertToShares(address(usdc), 4), 4e12);

        assertEq(psm.convertToShares(address(usdc), 1e6), 1e18);
        assertEq(psm.convertToShares(address(usdc), 2e6), 2e18);
        assertEq(psm.convertToShares(address(usdc), 3e6), 3e18);
        assertEq(psm.convertToShares(address(usdc), 4e6), 4e18);
    }

}

contract PSMConvertToSharesWithSDaiTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount, uint256 conversionRate) public {
        amount         = _bound(amount,         1000,    SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 1000e27);

        mockRateProvider.__setConversionRate(conversionRate);

        assertEq(psm.convertToShares(address(sDai), amount), amount * conversionRate / 1e27);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSDai_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(usdc), address(this), 100e6);
        _assertStartingConversionSDai();

        _deposit(address(sDai), address(this), 80e18);
        _assertStartingConversionSDai();

        _withdraw(address(usdc), address(this), 100e6);
        _assertStartingConversionSDai();

        _withdraw(address(sDai), address(this), 80e18);
        _assertStartingConversionSDai();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(sDai), address(this), 80e18);

        _assertStartingConversionSDai();

        // 80 sDAI now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10. Since 1 sDAI is now worth 1.5 USDC, 1 sDAI is worth
        // 1.50/1.10 = 1.3636... shares
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(sDai), 1), 0);
        assertEq(psm.convertToShares(address(sDai), 2), 2);
        assertEq(psm.convertToShares(address(sDai), 3), 3);  // 3 * 1.5 / 1.1 = 3 because of rounding on first operation
        assertEq(psm.convertToShares(address(sDai), 4), 5);

        assertEq(psm.convertToShares(address(sDai), 1e18), 1.363636363636363636e18);
        assertEq(psm.convertToShares(address(sDai), 2e18), 2.727272727272727272e18);
        assertEq(psm.convertToShares(address(sDai), 3e18), 4.090909090909090909e18);
        assertEq(psm.convertToShares(address(sDai), 4e18), 5.454545454545454545e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        // NOTE: Not using 1e27 for this test because initialSDaiValue needs to be different
        mockRateProvider.__setConversionRate(1.1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1.1e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue     = vars.expectedShares;
        uint256 initialSDaiValue = initialValue * 1e27 / 1.1e27;

        conversionRate = _bound(conversionRate, 1.1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            psm.convertToShares(address(sDai), initialSDaiValue),
            vars.expectedShares,
            1
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        uint256 newSDaiValue = newValue * 1e27 / conversionRate;

        // Depositing derived sDAI amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            psm.convertToShares(address(sDai), newSDaiValue),
            vars.expectedShares,
            1000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(sDai), newSDaiValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(sDai), newSDaiValue),
            (newSDaiValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from sDAI exchange rate increasing
        assertApproxEqAbs(
            newValue - initialValue,
            vars.sDaiAmount * (conversionRate - 1.1e27) / 1e27,
            3
        );
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 sDaiAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            daiAmount,
            usdcAmount,
            sDaiAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue     = vars.expectedShares;
        uint256 initialSDaiValue = initialValue * 1e27 / 2e27;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            psm.convertToShares(address(sDai), initialSDaiValue),
            vars.expectedShares,
            1
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.daiAmount + vars.usdcAmount * 1e12 + vars.sDaiAmount * conversionRate / 1e27;

        uint256 newSDaiValue = newValue * 1e27 / conversionRate;

        // Depositing derived sDAI amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            psm.convertToShares(address(sDai), newSDaiValue),
            vars.expectedShares,
            2000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(sDai), newSDaiValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(sDai), newSDaiValue),
            (newSDaiValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from sDAI exchange rate increasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.sDaiAmount * (2e27 - conversionRate) / 1e27,
            3
        );
    }

    function _assertOneToOneConversion() internal view {
        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(2), 2);
        assertEq(psm.convertToShares(3), 3);
        assertEq(psm.convertToShares(4), 4);

        assertEq(psm.convertToShares(1e18), 1e18);
        assertEq(psm.convertToShares(2e18), 2e18);
        assertEq(psm.convertToShares(3e18), 3e18);
        assertEq(psm.convertToShares(4e18), 4e18);
    }

    // NOTE: This is different because the dollar value of sDAI is 1.25x that of USDC
    function _assertStartingConversionSDai() internal view {
        assertEq(psm.convertToShares(address(sDai), 1), 1);
        assertEq(psm.convertToShares(address(sDai), 2), 2);
        assertEq(psm.convertToShares(address(sDai), 3), 3);
        assertEq(psm.convertToShares(address(sDai), 4), 5);

        assertEq(psm.convertToShares(address(sDai), 1e18), 1.25e18);
        assertEq(psm.convertToShares(address(sDai), 2e18), 2.5e18);
        assertEq(psm.convertToShares(address(sDai), 3e18), 3.75e18);
        assertEq(psm.convertToShares(address(sDai), 4e18), 5e18);
    }

}
