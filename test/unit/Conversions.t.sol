// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConversionTestBase is PSMTestBase {

    struct FuzzVars {
        uint256 usdsAmount;
        uint256 usdcAmount;
        uint256 susdsAmount;
        uint256 expectedShares;
    }

    // Takes in fuzz inputs, bounds them, deposits assets, and returns
    // initial shares from all deposits (always equal to total value at beginning).
    function _setUpConversionFuzzTest(
        uint256 initialConversionRate,
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount
    )
        internal returns (FuzzVars memory vars)
    {
        vars.usdsAmount  = _bound(usdsAmount,  1, USDS_TOKEN_MAX);
        vars.usdcAmount  = _bound(usdcAmount,  1, USDC_TOKEN_MAX);
        vars.susdsAmount = _bound(susdsAmount, 1, SUSDS_TOKEN_MAX);

        _deposit(address(usds),  address(this), vars.usdsAmount);
        _deposit(address(usdc),  address(this), vars.usdcAmount);
        _deposit(address(susds), address(this), vars.susdsAmount);

        vars.expectedShares =
            vars.usdsAmount +
            vars.usdcAmount * 1e12 +
            vars.susdsAmount * initialConversionRate / 1e27;

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
        assertEq(psm.convertToAssets(address(usds), 1), 1);
        assertEq(psm.convertToAssets(address(usds), 2), 2);
        assertEq(psm.convertToAssets(address(usds), 3), 3);

        assertEq(psm.convertToAssets(address(usds), 1e18), 1e18);
        assertEq(psm.convertToAssets(address(usds), 2e18), 2e18);
        assertEq(psm.convertToAssets(address(usds), 3e18), 3e18);

        assertEq(psm.convertToAssets(address(usdc), 1), 0);
        assertEq(psm.convertToAssets(address(usdc), 2), 0);
        assertEq(psm.convertToAssets(address(usdc), 3), 0);

        assertEq(psm.convertToAssets(address(usdc), 1e18), 1e6);
        assertEq(psm.convertToAssets(address(usdc), 2e18), 2e6);
        assertEq(psm.convertToAssets(address(usdc), 3e18), 3e6);

        assertEq(psm.convertToAssets(address(susds), 1), 0);
        assertEq(psm.convertToAssets(address(susds), 2), 1);
        assertEq(psm.convertToAssets(address(susds), 3), 2);

        assertEq(psm.convertToAssets(address(susds), 1e18), 0.8e18);
        assertEq(psm.convertToAssets(address(susds), 2e18), 1.6e18);
        assertEq(psm.convertToAssets(address(susds), 3e18), 2.4e18);
    }

    function testFuzz_convertToAssets_usdc(uint256 amount) public view {
        amount = _bound(amount, 0, USDS_TOKEN_MAX);

        assertEq(psm.convertToAssets(address(usds), amount), amount);
    }

    function testFuzz_convertToAssets_usds(uint256 amount) public view {
        amount = _bound(amount, 0, USDC_TOKEN_MAX);

        assertEq(psm.convertToAssets(address(usdc), amount), amount / 1e12);
    }

    function testFuzz_convertToAssets_susds(uint256 conversionRate, uint256 amount) public {
        // NOTE: 0.0001e27 considered lower bound for overflow considerations
        conversionRate = _bound(conversionRate, 0.0001e27, 1000e27);
        amount         = _bound(amount,         0,         SUSDS_TOKEN_MAX);

        mockRateProvider.__setConversionRate(conversionRate);

        assertEq(psm.convertToAssets(address(susds), amount), amount * 1e27 / conversionRate);
    }

}

contract PSMConvertToAssetValueTests is PSMConversionTestBase {

    function testFuzz_convertToAssetValue_noValue(uint256 amount) public view {
        assertEq(psm.convertToAssetValue(amount), amount);
    }

    function test_convertToAssetValue() public {
        _deposit(address(usds),  address(this), 100e18);
        _deposit(address(usdc),  address(this), 100e6);
        _deposit(address(susds), address(this), 80e18);

        assertEq(psm.convertToAssetValue(1e18), 1e18);

        mockRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // sUSDS portion becomes worth $160, full pool worth $360, each share worth $1.20
        assertEq(psm.convertToAssetValue(1e18), 1.2e18);
    }

    function testFuzz_convertToAssetValue_conversionRateIncrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToAssetValue(vars.expectedShares), initialValue);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from sUSDS exchange rate increasing
        assertEq(newValue - initialValue, vars.susdsAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToAssetValue(vars.expectedShares), initialValue);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToAssetValue(vars.expectedShares), newValue);

        // Value change is only from sUSDS exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.susdsAmount * (2e27 - conversionRate) / 1e27,
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

    function test_convertToShares_depositAndWithdrawUsdcAndSUsds_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(usdc), address(this), 100e6);
        _assertOneToOneConversion();

        _deposit(address(susds), address(this), 80e18);
        _assertOneToOneConversion();

        _withdraw(address(usdc), address(this), 100e6);
        _assertOneToOneConversion();

        _withdraw(address(susds), address(this), 80e18);
        _assertOneToOneConversion();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(susds), address(this), 80e18);

        _assertOneToOneConversion();

        // 80 sUSDS now worth $120, 200 shares in pool with $220 of value
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
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(newValue), vars.expectedShares);

        // Value change is only from sUSDS exchange rate increasing
        assertEq(newValue - initialValue, vars.susdsAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(newValue), vars.expectedShares);

        // Value change is only from sUSDS exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.susdsAmount * (2e27 - conversionRate) / 1e27,
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

contract PSMConvertToSharesWithUsdsTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversionUsds();
    }

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        amount = _bound(amount, 0, USDS_TOKEN_MAX);
        assertEq(psm.convertToShares(address(usds), amount), amount);
    }

    function test_convertToShares_depositAndWithdrawUsdsAndSUsds_noChange() public {
        _assertOneToOneConversionUsds();

        _deposit(address(usds), address(this), 100e18);
        _assertOneToOneConversionUsds();

        _deposit(address(susds), address(this), 80e18);
        _assertOneToOneConversionUsds();

        _withdraw(address(usds), address(this), 100e18);
        _assertOneToOneConversionUsds();

        _withdraw(address(susds), address(this), 80e18);
        _assertOneToOneConversionUsds();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usds),  address(this), 100e18);
        _deposit(address(susds), address(this), 80e18);

        _assertOneToOneConversionUsds();

        // 80 sUSDS now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10.
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(usds), 10), 9);
        assertEq(psm.convertToShares(address(usds), 11), 10);
        assertEq(psm.convertToShares(address(usds), 12), 10);

        assertEq(psm.convertToShares(address(usds), 10e18), 9.090909090909090909e18);
        assertEq(psm.convertToShares(address(usds), 11e18), 10e18);
        assertEq(psm.convertToShares(address(usds), 12e18), 10.909090909090909090e18);
    }

    // NOTE: These tests will be the exact same as convertToShares(amount) tests because USDS is an
    //       18 decimal precision asset pegged to the dollar, which is whats used for "value".

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(address(usds), initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(address(usds), newValue), vars.expectedShares);

        // Value change is only from sUSDS exchange rate increasing
        assertEq(newValue - initialValue, vars.susdsAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue = vars.expectedShares;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertEq(psm.convertToShares(address(usds), initialValue), vars.expectedShares);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        assertEq(psm.convertToShares(address(usds), newValue), vars.expectedShares);

        // Value change is only from sUSDS exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.susdsAmount * (2e27 - conversionRate) / 1e27,
            1
        );
    }

    function _assertOneToOneConversionUsds() internal view {
        assertEq(psm.convertToShares(address(usds), 1), 1);
        assertEq(psm.convertToShares(address(usds), 2), 2);
        assertEq(psm.convertToShares(address(usds), 3), 3);
        assertEq(psm.convertToShares(address(usds), 4), 4);

        assertEq(psm.convertToShares(address(usds), 1e18), 1e18);
        assertEq(psm.convertToShares(address(usds), 2e18), 2e18);
        assertEq(psm.convertToShares(address(usds), 3e18), 3e18);
        assertEq(psm.convertToShares(address(usds), 4e18), 4e18);
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

    function test_convertToShares_depositAndWithdrawUsdcAndSUsds_noChange() public {
        _assertOneToOneConversionUsdc();

        _deposit(address(usdc), address(this), 100e6);
        _assertOneToOneConversionUsdc();

        _deposit(address(susds), address(this), 80e18);
        _assertOneToOneConversionUsdc();

        _withdraw(address(usdc), address(this), 100e6);
        _assertOneToOneConversionUsdc();

        _withdraw(address(susds), address(this), 80e18);
        _assertOneToOneConversionUsdc();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc),  address(this), 100e6);
        _deposit(address(susds), address(this), 80e18);

        _assertOneToOneConversionUsdc();

        // 80 sUSDS now worth $120, 200 shares in pool with $220 of value
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
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
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
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

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

        // Value change is only from sUSDS exchange rate increasing
        assertEq(newValue - initialValue, vars.susdsAmount * (conversionRate - 1e27) / 1e27);
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
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
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

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

        // Value change is only from sUSDS exchange rate decreasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.susdsAmount * (2e27 - conversionRate) / 1e27,
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

contract PSMConvertToSharesWithSUsdsTests is PSMConversionTestBase {

    function test_convertToShares_noValue() public view {
        _assertOneToOneConversion();
    }

    function testFuzz_convertToShares_noValue(uint256 amount, uint256 conversionRate) public {
        amount         = _bound(amount,         1000,    SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 0.01e27, 1000e27);

        mockRateProvider.__setConversionRate(conversionRate);

        assertEq(psm.convertToShares(address(susds), amount), amount * conversionRate / 1e27);
    }

    function test_convertToShares_depositAndWithdrawUsdcAndSUsds_noChange() public {
        _assertOneToOneConversion();

        _deposit(address(usdc), address(this), 100e6);
        _assertStartingConversionSUsds();

        _deposit(address(susds), address(this), 80e18);
        _assertStartingConversionSUsds();

        _withdraw(address(usdc), address(this), 100e6);
        _assertStartingConversionSUsds();

        _withdraw(address(susds), address(this), 80e18);
        _assertStartingConversionSUsds();
    }

    function test_convertToShares_conversionRateIncrease() public {
        // 200 shares minted at 1:1 ratio, $200 of value in pool
        _deposit(address(usdc), address(this), 100e6);
        _deposit(address(susds), address(this), 80e18);

        _assertStartingConversionSUsds();

        // 80 sUSDS now worth $120, 200 shares in pool with $220 of value
        // Each share should be worth $1.10. Since 1 sUSDS is now worth 1.5 USDC, 1 sUSDS is worth
        // 1.50/1.10 = 1.3636... shares
        mockRateProvider.__setConversionRate(1.5e27);

        assertEq(psm.convertToShares(address(susds), 1), 0);
        assertEq(psm.convertToShares(address(susds), 2), 2);
        assertEq(psm.convertToShares(address(susds), 3), 3);  // 3 * 1.5 / 1.1 = 3 because of rounding on first operation
        assertEq(psm.convertToShares(address(susds), 4), 5);

        assertEq(psm.convertToShares(address(susds), 1e18), 1.363636363636363636e18);
        assertEq(psm.convertToShares(address(susds), 2e18), 2.727272727272727272e18);
        assertEq(psm.convertToShares(address(susds), 3e18), 4.090909090909090909e18);
        assertEq(psm.convertToShares(address(susds), 4e18), 5.454545454545454545e18);
    }

    function testFuzz_convertToShares_conversionRateIncrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        // NOTE: Not using 1e27 for this test because initialSUsdsValue needs to be different
        mockRateProvider.__setConversionRate(1.1e27);  // Start lower than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            1.1e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue     = vars.expectedShares;
        uint256 initialSUsdsValue = initialValue * 1e27 / 1.1e27;

        conversionRate = _bound(conversionRate, 1.1e27, 1000e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            psm.convertToShares(address(susds), initialSUsdsValue),
            vars.expectedShares,
            1
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        uint256 newSUsdsValue = newValue * 1e27 / conversionRate;

        // Depositing derived sUSDS amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            psm.convertToShares(address(susds), newSUsdsValue),
            vars.expectedShares,
            1000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(susds), newSUsdsValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(susds), newSUsdsValue),
            (newSUsdsValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from sUSDS exchange rate increasing
        assertApproxEqAbs(
            newValue - initialValue,
            vars.susdsAmount * (conversionRate - 1.1e27) / 1e27,
            3
        );
    }

    function testFuzz_convertToAssetValue_conversionRateDecrease(
        uint256 usdsAmount,
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        mockRateProvider.__setConversionRate(2e27);  // Start higher than 1.25 for this test

        FuzzVars memory vars = _setUpConversionFuzzTest(
            2e27,
            usdsAmount,
            usdcAmount,
            susdsAmount
        );

        // These two values are always the same at the beginning
        uint256 initialValue      = vars.expectedShares;
        uint256 initialSUsdsValue = initialValue * 1e27 / 2e27;

        conversionRate = _bound(conversionRate, 0.001e27, 2e27);

        // 1:1 between shares and dollar value
        assertApproxEqAbs(
            psm.convertToShares(address(susds), initialSUsdsValue),
            vars.expectedShares,
            1
        );

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 newValue
            = vars.usdsAmount + vars.usdcAmount * 1e12 + vars.susdsAmount * conversionRate / 1e27;

        uint256 newSUsdsValue = newValue * 1e27 / conversionRate;

        // Depositing derived sUSDS amount yields the same amount of shares (approx)
        assertApproxEqAbs(
            psm.convertToShares(address(susds), newSUsdsValue),
            vars.expectedShares,
            2000
        );

        // Make sure that rounding error here is always against the user
        assertLe(
            psm.convertToShares(address(susds), newSUsdsValue),
            vars.expectedShares
        );

        // This is the exact calculation of what is happening
        assertEq(
            psm.convertToShares(address(susds), newSUsdsValue),
            (newSUsdsValue * conversionRate / 1e27) * vars.expectedShares / newValue
        );

        // Value change is only from sUSDS exchange rate increasing
        assertApproxEqAbs(
            initialValue - newValue,
            vars.susdsAmount * (2e27 - conversionRate) / 1e27,
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

    // NOTE: This is different because the dollar value of sUSDS is 1.25x that of USDC
    function _assertStartingConversionSUsds() internal view {
        assertEq(psm.convertToShares(address(susds), 1), 1);
        assertEq(psm.convertToShares(address(susds), 2), 2);
        assertEq(psm.convertToShares(address(susds), 3), 3);
        assertEq(psm.convertToShares(address(susds), 4), 5);

        assertEq(psm.convertToShares(address(susds), 1e18), 1.25e18);
        assertEq(psm.convertToShares(address(susds), 2e18), 2.5e18);
        assertEq(psm.convertToShares(address(susds), 3e18), 3.75e18);
        assertEq(psm.convertToShares(address(susds), 4e18), 5e18);
    }

}
