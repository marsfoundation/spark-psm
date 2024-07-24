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

    function test_previewWithdraw_zeroTotalAssets() public {
        ( uint256 shares1, uint256 assets1 ) = psm.previewWithdraw(address(dai),  1e18);
        ( uint256 shares2, uint256 assets2 ) = psm.previewWithdraw(address(usdc), 1e6);
        ( uint256 shares3, uint256 assets3 ) = psm.previewWithdraw(address(sDai), 1e18);

        assertEq(shares1, 0);
        assertEq(assets1, 0);
        assertEq(shares2, 0);
        assertEq(assets2, 0);
        assertEq(shares3, 0);
        assertEq(assets3, 0);

        mockRateProvider.__setConversionRate(2e27);

        ( shares1, assets1 ) = psm.previewWithdraw(address(dai),  1e18);
        ( shares2, assets2 ) = psm.previewWithdraw(address(usdc), 1e6);
        ( shares3, assets3 ) = psm.previewWithdraw(address(sDai), 1e18);

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
        // balance of sDAI and USDC
        _deposit(address(dai),  address(this),         100e18);
        _deposit(address(usdc), makeAddr("usdc-user"), 10e6);
        _deposit(address(sDai), makeAddr("sDai-user"), 1e18);
    }

    function test_previewWithdraw_dai_amountLtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(dai), 100e18 - 1);
        assertEq(shares, 100e18 - 1);
        assertEq(assets, 100e18 - 1);
    }

    function test_previewWithdraw_dai_amountEqUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(dai), 100e18);
        assertEq(shares, 100e18);
        assertEq(assets, 100e18);
    }

    function test_previewWithdraw_dai_amountGtUnderlyingBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(dai), 100e18 + 1);
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

    function test_previewWithdraw_sdai_amountLtUnderlyingBalanceAndLtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(sDai), 1e18 - 1);
        assertEq(shares, 1.25e18 - 2);
        assertEq(assets, 1e18 - 1);
    }

    function test_previewWithdraw_sdai_amountLtUnderlyingBalanceAndEqPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(sDai), 1e18);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

    function test_previewWithdraw_sdai_amountLtUnderlyingBalanceAndGtPsmBalance() public view {
        ( uint256 shares, uint256 assets ) = psm.previewWithdraw(address(sDai), 1e18 + 1);
        assertEq(shares, 1.25e18);
        assertEq(assets, 1e18);
    }

}
