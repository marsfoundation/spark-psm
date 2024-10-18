// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewWithdraw_FailureTests is PSMTestBase {

    function test_previewWithdraw_invalidAsset() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewWithdraw(makeAddr("other-token"), 1);
    }

}

contract PSMPreviewWithdraw_ZeroAssetsTests is PSMTestBase {

    // Always returns zero because there is no balance of assets in the PSM in this case
    function test_previewWithdraw_zeroTotalAssets() public {
        ( uint256 shares1, uint256 assets1 ) = psm.previewWithdraw(address(usds),  1e18);
        ( uint256 shares2, uint256 assets2 ) = psm.previewWithdraw(address(usdc),  1e6);
        ( uint256 shares3, uint256 assets3 ) = psm.previewWithdraw(address(susds), 1e18);

        assertEq(shares1, 0);
        assertEq(assets1, 0);
        assertEq(shares2, 0);
        assertEq(assets2, 0);
        assertEq(shares3, 0);
        assertEq(assets3, 0);

        mockRateProvider.__setConversionRate(2e27);

        ( shares1, assets1 ) = psm.previewWithdraw(address(usds),  1e18);
        ( shares2, assets2 ) = psm.previewWithdraw(address(usdc),  1e6);
        ( shares3, assets3 ) = psm.previewWithdraw(address(susds), 1e18);

        assertEq(shares1, 0);
        assertEq(assets1, 0);
        assertEq(shares2, 0);
        assertEq(assets2, 0);
        assertEq(shares3, 0);
        assertEq(assets3, 0);
    }

}

contract PSMPreviewWithdraw_SuccessTests is PSMTestBase {

    function setUp() public override {
        super.setUp();
        // Setup so that address(this) has the most shares, higher underlying balance than PSM
        // balance of sUSDS and USDC
        _deposit(address(usds),  address(this),          100e18);
        _deposit(address(usdc),  makeAddr("usdc-user"),  10e6);
        _deposit(address(susds), makeAddr("susds-user"), 1e18);
    }

    function test_previewWithdraw_usds_amountLtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usds), 100e18 - 1);
        assertEq(shares, 100e18 - 1);
        assertEq(assets, 100e18 - 1);
    }

    function test_previewWithdraw_usds_amountEqUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usds), 100e18);
        assertEq(shares, 100e18);
        assertEq(assets, 100e18);
    }

    function test_previewWithdraw_usds_amountGtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usds), 100e18 + 1);
        assertEq(shares, 100e18);
        assertEq(assets, 100e18);
    }

    function test_previewWithdraw_usdc_amountLtUnderlyingBalanceAndLtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usdc), 10e6 - 1);
        assertEq(shares, 10e18 - 1e12);
        assertEq(assets, 10e6 - 1);
    }

    function test_previewWithdraw_usdc_amountLtUnderlyingBalanceAndEqPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usdc), 10e6);
        assertEq(shares, 10e18);
        assertEq(assets, 10e6);
    }

    function test_previewWithdraw_usdc_amountLtUnderlyingBalanceAndGtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(usdc), 10e6 + 1);
        assertEq(shares, 10e18);
        assertEq(assets, 10e6);
    }

    function test_previewWithdraw_susds_amountLtUnderlyingBalanceAndLtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(susds), 1e18 - 1);
        assertEq(shares, 1.25e18 - 1);
        assertEq(assets, 1e18 - 1);
    }

    function test_previewWithdraw_susds_amountLtUnderlyingBalanceAndEqPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(susds), 1e18);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

    function test_previewWithdraw_susds_amountLtUnderlyingBalanceAndGtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(susds), 1e18 + 1);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

}

contract PSMPreviewWithdraw_SuccessFuzzTests is PSMTestBase {

    struct TestParams {
        uint256 amount1;
        uint256 amount2;
        uint256 amount3;
        uint256 previewAmount1;
        uint256 previewAmount2;
        uint256 previewAmount3;
        uint256 conversionRate;
    }

    function testFuzz_previewWithdraw(TestParams memory params) public {
        params.amount1 = _bound(params.amount1, 1, USDS_TOKEN_MAX);
        params.amount2 = _bound(params.amount2, 1, USDC_TOKEN_MAX);
        params.amount3 = _bound(params.amount3, 1, SUSDS_TOKEN_MAX);

        // Only covering case of amount being below underlying to focus on value conversion
        // and avoid reimplementation of contract logic for dealing with capping amounts
        params.previewAmount1 = _bound(params.previewAmount1, 0, params.amount1);
        params.previewAmount2 = _bound(params.previewAmount2, 0, params.amount2);
        params.previewAmount3 = _bound(params.previewAmount3, 0, params.amount3);

        _deposit(address(usds),  address(this), params.amount1);
        _deposit(address(usdc),  address(this), params.amount2);
        _deposit(address(susds), address(this), params.amount3);

        ( uint256 shares1, uint256 assets1 ) = psm.previewWithdraw(address(usds),  params.previewAmount1);
        ( uint256 shares2, uint256 assets2 ) = psm.previewWithdraw(address(usdc),  params.previewAmount2);
        ( uint256 shares3, uint256 assets3 ) = psm.previewWithdraw(address(susds), params.previewAmount3);

        uint256 totalSharesMinted = params.amount1 + params.amount2 * 1e12 + params.amount3 * 1.25e27 / 1e27;
        uint256 totalValue        = totalSharesMinted;

        // Assert shares are always rounded up, max of 1 wei difference except for sUSDS
        assertLe(shares1 - (params.previewAmount1                  * totalSharesMinted / totalValue), 1);
        assertLe(shares2 - (params.previewAmount2 * 1e12           * totalSharesMinted / totalValue), 1);
        assertLe(shares3 - (params.previewAmount3 * 1.25e27 / 1e27 * totalSharesMinted / totalValue), 3);

        assertEq(assets1, params.previewAmount1);
        assertEq(assets2, params.previewAmount2);
        assertEq(assets3, params.previewAmount3);

        params.conversionRate = _bound(params.conversionRate, 0.001e27, 1000e27);
        mockRateProvider.__setConversionRate(params.conversionRate);

        // susds value accrual changes the value of shares in the PSM
        totalValue = params.amount1 + params.amount2 * 1e12 + params.amount3 * params.conversionRate / 1e27;

        ( shares1, assets1 ) = psm.previewWithdraw(address(usds),  params.previewAmount1);
        ( shares2, assets2 ) = psm.previewWithdraw(address(usdc),  params.previewAmount2);
        ( shares3, assets3 ) = psm.previewWithdraw(address(susds), params.previewAmount3);

        uint256 susdsConvertedAmount = params.previewAmount3 * params.conversionRate / 1e27;

        // Assert shares are always rounded up, max of 1 wei difference except for sUSDS
        // totalSharesMinted / totalValue is an integer amount that scales as the rate scales by orders of magnitude
        assertLe(shares1 - (params.previewAmount1        * totalSharesMinted / totalValue), 1);
        assertLe(shares2 - (params.previewAmount2 * 1e12 * totalSharesMinted / totalValue), 1);
        assertLe(shares3 - (susdsConvertedAmount         * totalSharesMinted / totalValue), 3 + totalSharesMinted / totalValue);

        assertApproxEqAbs(assets1, params.previewAmount1, 1);
        assertApproxEqAbs(assets2, params.previewAmount2, 1);
        assertApproxEqAbs(assets3, params.previewAmount3, 1);
    }

}
