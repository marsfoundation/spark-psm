// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMPreviewDeposit_FailureTests is PSMTestBase {

    function test_previewDeposit_invalidAsset() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.previewDeposit(makeAddr("other-token"), 1);
    }

}

contract PSMPreviewDeposit_SuccessTests is PSMTestBase {

    address depositor = makeAddr("depositor");

    function test_previewDeposit_usdc_firstDeposit() public view {
        assertEq(psm.previewDeposit(address(usdc), 1), 1e12);
        assertEq(psm.previewDeposit(address(usdc), 2), 2e12);
        assertEq(psm.previewDeposit(address(usdc), 3), 3e12);

        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);
        assertEq(psm.previewDeposit(address(usdc), 2e6), 2e18);
        assertEq(psm.previewDeposit(address(usdc), 3e6), 3e18);
    }

    function testFuzz_previewDeposit_usdc_firstDeposit(uint256 amount) public view {
        amount = _bound(amount, 0, USDC_TOKEN_MAX);
        assertEq(psm.previewDeposit(address(usdc), amount), amount * 1e12);
    }

    function test_previewDeposit_usdc_notOneToOne() public {
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(dai), depositor, 1e18);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(usdc), depositor, 1e6);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(sDai), depositor, 0.8e18);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        mockRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // sDAI portion becomes worth $160, full pool worth $360, each share worth $1.20
        // 1 USDC = 1/1.20 = 0.833...
        assertEq(psm.previewDeposit(address(usdc), 1e6), 0.833333333333333333e18);
    }

    function test_previewDeposit_usdc_notOneToOne(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        uint256 conversionRate,
        uint256 previewAmount
    ) public {
        amount1        = _bound(amount1,        1,       DAI_TOKEN_MAX);
        amount2        = _bound(amount2,        1,       USDC_TOKEN_MAX);
        amount3        = _bound(amount3,        1,       SDAI_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 1.00e27, 1000e27);
        previewAmount  = _bound(previewAmount,  0,       USDC_TOKEN_MAX);

        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(dai), depositor, 1e18);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(usdc), depositor, 1e6);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        _deposit(address(sDai), depositor, 0.8e18);
        assertEq(psm.previewDeposit(address(usdc), 1e6), 1e18);

        mockRateProvider.__setConversionRate(2e27);

        // $300 dollars of value deposited, 300 shares minted.
        // sDAI portion becomes worth $160, full pool worth $360, each share worth $1.20
        // 1 USDC = 1/1.20 = 0.833...
        assertEq(psm.previewDeposit(address(usdc), 1e6), 0.833333333333333333e18);
    }

}
