// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMDepositTests is PSMTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_deposit_zeroReceiver() public {
        vm.expectRevert("PSM3/invalid-receiver");
        psm.deposit(address(usdc), address(0), 100e6);
    }

    function test_deposit_zeroAmount() public {
        vm.expectRevert("PSM3/invalid-amount");
        psm.deposit(address(usdc), user1, 0);
    }

    function test_deposit_notAsset0OrAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.deposit(makeAddr("new-asset"), user1, 100e6);
    }

    function test_deposit_insufficientApproveBoundary() public {
        dai.mint(user1, 100e18);

        vm.startPrank(user1);

        dai.approve(address(psm), 100e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.deposit(address(dai), user1, 100e18);

        dai.approve(address(psm), 100e18);

        psm.deposit(address(dai), user1, 100e18);
    }

    function test_deposit_insufficientBalanceBoundary() public {
        dai.mint(user1, 100e18 - 1);

        vm.startPrank(user1);

        dai.approve(address(psm), 100e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.deposit(address(dai), user1, 100e18);

        dai.mint(user1, 1);

        psm.deposit(address(dai), user1, 100e18);
    }

    function test_deposit_firstDepositDai() public {
        dai.mint(user1, 100e18);

        vm.startPrank(user1);

        dai.approve(address(psm), 100e18);

        assertEq(dai.allowance(user1, address(psm)), 100e18);
        assertEq(dai.balanceOf(user1),               100e18);
        assertEq(dai.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(dai), receiver1, 100e18);

        assertEq(newShares, 100e18);

        assertEq(dai.allowance(user1, address(psm)), 0);
        assertEq(dai.balanceOf(user1),               0);
        assertEq(dai.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     100e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositUsdc() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(psm), 100e6);

        assertEq(usdc.allowance(user1, address(psm)), 100e6);
        assertEq(usdc.balanceOf(user1),               100e6);
        assertEq(usdc.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(usdc.allowance(user1, address(psm)), 0);
        assertEq(usdc.balanceOf(user1),               0);
        assertEq(usdc.balanceOf(address(psm)),        100e6);

        assertEq(psm.totalShares(),     100e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSDai() public {
        sDai.mint(user1, 100e18);

        vm.startPrank(user1);

        sDai.approve(address(psm), 100e18);

        assertEq(sDai.allowance(user1, address(psm)), 100e18);
        assertEq(sDai.balanceOf(user1),               100e18);
        assertEq(sDai.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(sDai), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(sDai.allowance(user1, address(psm)), 0);
        assertEq(sDai.balanceOf(user1),               0);
        assertEq(sDai.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     125e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_usdcThenSDai() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(psm), 100e6);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        sDai.mint(user1, 100e18);
        sDai.approve(address(psm), 100e18);

        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.allowance(user1, address(psm)), 100e18);
        assertEq(sDai.balanceOf(user1),               100e18);
        assertEq(sDai.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     100e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        newShares = psm.deposit(address(sDai), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.allowance(user1, address(psm)), 0);
        assertEq(sDai.balanceOf(user1),               0);
        assertEq(sDai.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     225e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_usdcThenSDai(uint256 usdcAmount, uint256 sDaiAmount) public {
        // Zero amounts revert
        usdcAmount = _bound(usdcAmount, 1, USDC_TOKEN_MAX);
        sDaiAmount = _bound(sDaiAmount, 1, SDAI_TOKEN_MAX);

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(psm), usdcAmount);

        uint256 newShares = psm.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        sDai.mint(user1, sDaiAmount);
        sDai.approve(address(psm), sDaiAmount);

        assertEq(usdc.balanceOf(address(psm)), usdcAmount);

        assertEq(sDai.allowance(user1, address(psm)), sDaiAmount);
        assertEq(sDai.balanceOf(user1),               sDaiAmount);
        assertEq(sDai.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     usdcAmount * 1e12);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), usdcAmount * 1e12);

        assertEq(psm.convertToShares(1e18), 1e18);

        newShares = psm.deposit(address(sDai), receiver1, sDaiAmount);

        assertEq(newShares, sDaiAmount * 125/100);

        assertEq(usdc.balanceOf(address(psm)), usdcAmount);

        assertEq(sDai.allowance(user1, address(psm)), 0);
        assertEq(sDai.balanceOf(user1),               0);
        assertEq(sDai.balanceOf(address(psm)),        sDaiAmount);

        assertEq(psm.totalShares(),     usdcAmount * 1e12 + sDaiAmount * 125/100);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), usdcAmount * 1e12 + sDaiAmount * 125/100);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_multiUser_changeConversionRate() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(psm), 100e6);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        sDai.mint(user1, 100e18);
        sDai.approve(address(psm), 100e18);

        newShares = psm.deposit(address(sDai), receiver1, 100e18);

        assertEq(newShares, 125e18);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.allowance(user1, address(psm)), 0);
        assertEq(sDai.balanceOf(user1),               0);
        assertEq(sDai.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     225e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        assertEq(psm.convertToAssetValue(psm.shares(receiver1)), 225e18);

        MockRateProvider(address(rateProvider)).__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 sDAI value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(psm.convertToShares(1e18), expectedConversionRate);

        vm.startPrank(user2);

        sDai.mint(user2, 100e18);
        sDai.approve(address(psm), 100e18);

        assertEq(sDai.allowance(user2, address(psm)), 100e18);
        assertEq(sDai.balanceOf(user2),               100e18);
        assertEq(sDai.balanceOf(address(psm)),        100e18);

        assertEq(psm.convertToAssetValue(psm.shares(receiver1)), 250e18);
        assertEq(psm.convertToAssetValue(psm.shares(receiver2)), 0);

        assertEq(psm.getPsmTotalValue(), 250e18);

        newShares = psm.deposit(address(sDai), receiver2, 100e18);

        assertEq(newShares, 135e18);

        assertEq(sDai.allowance(user2, address(psm)), 0);
        assertEq(sDai.balanceOf(user2),               0);
        assertEq(sDai.balanceOf(address(psm)),        200e18);

        // Depositing 150 dollars of value at 0.9 exchange rate
        uint256 expectedShares = 150e18 * 9/10;

        assertEq(expectedShares, 135e18);

        assertEq(psm.totalShares(),     360e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(user2),     0);
        assertEq(psm.shares(receiver1), 225e18);
        assertEq(psm.shares(receiver2), 135e18);

        // Receiver 1 earned $25 on 225, Receiver 2 has earned nothing
        assertEq(psm.convertToAssetValue(psm.shares(receiver1)), 250e18);
        assertEq(psm.convertToAssetValue(psm.shares(receiver2)), 150e18);

        assertEq(psm.getPsmTotalValue(), 400e18);
    }

    function testFuzz_deposit_multiUser_changeConversionRate(
        uint256 usdcAmount,
        uint256 sDaiAmount1,
        uint256 sDaiAmount2,
        uint256 newRate
    )
        public
    {
        // Zero amounts revert
        usdcAmount  = _bound(usdcAmount,  1,       USDC_TOKEN_MAX);
        sDaiAmount1 = _bound(sDaiAmount1, 1,       SDAI_TOKEN_MAX);
        sDaiAmount2 = _bound(sDaiAmount2, 1,       SDAI_TOKEN_MAX);
        newRate     = _bound(newRate,     1.25e27, 1000e27);

        uint256 user1DepositValue = usdcAmount * 1e12 + sDaiAmount1 * 125/100;

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(psm), usdcAmount);

        uint256 newShares = psm.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        sDai.mint(user1, sDaiAmount1);
        sDai.approve(address(psm), sDaiAmount1);

        newShares = psm.deposit(address(sDai), receiver1, sDaiAmount1);

        assertEq(newShares, sDaiAmount1 * 125/100);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(psm)), usdcAmount);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(address(psm)), sDaiAmount1);

        // Deposited at 1:1 conversion
        uint256 receiver1Shares = user1DepositValue;

        assertEq(psm.totalShares(),     receiver1Shares);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), receiver1Shares);

        MockRateProvider(address(rateProvider)).__setConversionRate(newRate);

        vm.startPrank(user2);

        sDai.mint(user2, sDaiAmount2);
        sDai.approve(address(psm), sDaiAmount2);

        assertEq(sDai.allowance(user2, address(psm)), sDaiAmount2);
        assertEq(sDai.balanceOf(user2),               sDaiAmount2);
        assertEq(sDai.balanceOf(address(psm)),        sDaiAmount1);

        // Receiver1 has gained from conversion change
        uint256 receiver1NewValue = user1DepositValue + sDaiAmount1 * (newRate - 1.25e27) / 1e27;

        // Receiver1 has gained from conversion change
        assertApproxEqAbs(
            psm.convertToAssetValue(psm.shares(receiver1)),
            receiver1NewValue,
            1
        );

        assertEq(psm.convertToAssetValue(psm.shares(receiver2)), 0);

        assertApproxEqAbs(psm.getPsmTotalValue(), receiver1NewValue, 1);

        newShares = psm.deposit(address(sDai), receiver2, sDaiAmount2);

        // Using queried values here instead of derived to avoid larger errors getting introduced
        // Assertions above prove that these values are as expected.
        uint256 receiver2Shares
            = (sDaiAmount2 * newRate / 1e27) * psm.totalShares() / psm.getPsmTotalValue();

        assertApproxEqAbs(newShares, receiver2Shares, 2);

        assertEq(sDai.allowance(user2, address(psm)), 0);
        assertEq(sDai.balanceOf(user2),               0);
        assertEq(sDai.balanceOf(address(psm)),        sDaiAmount1 + sDaiAmount2);

        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        assertApproxEqAbs(psm.totalShares(),     receiver1Shares + receiver2Shares, 2);
        assertApproxEqAbs(psm.shares(receiver1), receiver1Shares,                   2);
        assertApproxEqAbs(psm.shares(receiver2), receiver2Shares,                   2);

        uint256 receiver2NewValue = sDaiAmount2 * newRate / 1e27;

        // Rate change of up to 1000x introduces errors
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(receiver1)), receiver1NewValue, 1000);
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(receiver2)), receiver2NewValue, 1000);

        assertApproxEqAbs(psm.getPsmTotalValue(), receiver1NewValue + receiver2NewValue, 1000);
    }

}
