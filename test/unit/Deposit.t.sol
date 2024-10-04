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

    function test_deposit_zeroAmount() public {
        vm.expectRevert("PSM3/invalid-amount");
        psm.deposit(address(usdc), user1, 0);
    }

    function test_deposit_invalidAsset() public {
        // NOTE: This reverts in _getAssetValue
        vm.expectRevert("PSM3/invalid-asset-for-value");
        psm.deposit(makeAddr("new-asset"), user1, 100e6);
    }

    function test_deposit_insufficientApproveBoundary() public {
        usds.mint(user1, 100e18);

        vm.startPrank(user1);

        usds.approve(address(psm), 100e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.deposit(address(usds), user1, 100e18);

        usds.approve(address(psm), 100e18);

        psm.deposit(address(usds), user1, 100e18);
    }

    function test_deposit_insufficientBalanceBoundary() public {
        usds.mint(user1, 100e18 - 1);

        vm.startPrank(user1);

        usds.approve(address(psm), 100e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.deposit(address(usds), user1, 100e18);

        usds.mint(user1, 1);

        psm.deposit(address(usds), user1, 100e18);
    }

    function test_deposit_firstDepositUsds() public {
        usds.mint(user1, 100e18);

        vm.startPrank(user1);

        usds.approve(address(psm), 100e18);

        assertEq(usds.allowance(user1, address(psm)), 100e18);
        assertEq(usds.balanceOf(user1),               100e18);
        assertEq(usds.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(usds), receiver1, 100e18);

        assertEq(newShares, 100e18);

        assertEq(usds.allowance(user1, address(psm)), 0);
        assertEq(usds.balanceOf(user1),               0);
        assertEq(usds.balanceOf(address(psm)),        100e18);

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
        assertEq(usdc.balanceOf(pocket),              0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        assertEq(usdc.allowance(user1, address(psm)), 0);
        assertEq(usdc.balanceOf(user1),               0);
        assertEq(usdc.balanceOf(pocket),              100e6);

        assertEq(psm.totalShares(),     100e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSUsds() public {
        susds.mint(user1, 100e18);

        vm.startPrank(user1);

        susds.approve(address(psm), 100e18);

        assertEq(susds.allowance(user1, address(psm)), 100e18);
        assertEq(susds.balanceOf(user1),               100e18);
        assertEq(susds.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     0);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);

        uint256 newShares = psm.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(susds.allowance(user1, address(psm)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     125e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_usdcThenSUsds() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(psm), 100e6);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        susds.mint(user1, 100e18);
        susds.approve(address(psm), 100e18);

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(psm)), 100e18);
        assertEq(susds.balanceOf(user1),               100e18);
        assertEq(susds.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     100e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        newShares = psm.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(psm)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     225e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_usdcThenSUsds(uint256 usdcAmount, uint256 susdsAmount) public {
        // Zero amounts revert
        usdcAmount = _bound(usdcAmount, 1, USDC_TOKEN_MAX);
        susdsAmount = _bound(susdsAmount, 1, SUSDS_TOKEN_MAX);

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(psm), usdcAmount);

        uint256 newShares = psm.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        susds.mint(user1, susdsAmount);
        susds.approve(address(psm), susdsAmount);

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.allowance(user1, address(psm)), susdsAmount);
        assertEq(susds.balanceOf(user1),               susdsAmount);
        assertEq(susds.balanceOf(address(psm)),        0);

        assertEq(psm.totalShares(),     usdcAmount * 1e12);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), usdcAmount * 1e12);

        assertEq(psm.convertToShares(1e18), 1e18);

        newShares = psm.deposit(address(susds), receiver1, susdsAmount);

        assertEq(newShares, susdsAmount * 125/100);

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.allowance(user1, address(psm)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(psm)),        susdsAmount);

        assertEq(psm.totalShares(),     usdcAmount * 1e12 + susdsAmount * 125/100);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), usdcAmount * 1e12 + susdsAmount * 125/100);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_multiUser_changeConversionRate() public {
        usdc.mint(user1, 100e6);

        vm.startPrank(user1);

        usdc.approve(address(psm), 100e6);

        uint256 newShares = psm.deposit(address(usdc), receiver1, 100e6);

        assertEq(newShares, 100e18);

        susds.mint(user1, 100e18);
        susds.approve(address(psm), 100e18);

        newShares = psm.deposit(address(susds), receiver1, 100e18);

        assertEq(newShares, 125e18);

        vm.stopPrank();

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(susds.allowance(user1, address(psm)), 0);
        assertEq(susds.balanceOf(user1),               0);
        assertEq(susds.balanceOf(address(psm)),        100e18);

        assertEq(psm.totalShares(),     225e18);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        assertEq(psm.convertToAssetValue(psm.shares(receiver1)), 225e18);

        mockRateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 sUSDS value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(psm.convertToShares(1e18), expectedConversionRate);

        vm.startPrank(user2);

        susds.mint(user2, 100e18);
        susds.approve(address(psm), 100e18);

        assertEq(susds.allowance(user2, address(psm)), 100e18);
        assertEq(susds.balanceOf(user2),               100e18);
        assertEq(susds.balanceOf(address(psm)),        100e18);

        assertEq(psm.convertToAssetValue(psm.shares(receiver1)), 250e18);
        assertEq(psm.convertToAssetValue(psm.shares(receiver2)), 0);

        assertEq(psm.totalAssets(), 250e18);

        newShares = psm.deposit(address(susds), receiver2, 100e18);

        assertEq(newShares, 135e18);

        assertEq(susds.allowance(user2, address(psm)), 0);
        assertEq(susds.balanceOf(user2),               0);
        assertEq(susds.balanceOf(address(psm)),        200e18);

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

        assertEq(psm.totalAssets(), 400e18);
    }

    function testFuzz_deposit_multiUser_changeConversionRate(
        uint256 usdcAmount,
        uint256 susdsAmount1,
        uint256 susdsAmount2,
        uint256 newRate
    )
        public
    {
        // Zero amounts revert
        usdcAmount   = _bound(usdcAmount,   1,       USDC_TOKEN_MAX);
        susdsAmount1 = _bound(susdsAmount1, 1,       SUSDS_TOKEN_MAX);
        susdsAmount2 = _bound(susdsAmount2, 1,       SUSDS_TOKEN_MAX);
        newRate      = _bound(newRate,      1.25e27, 1000e27);

        uint256 user1DepositValue = usdcAmount * 1e12 + susdsAmount1 * 125/100;

        usdc.mint(user1, usdcAmount);

        vm.startPrank(user1);

        usdc.approve(address(psm), usdcAmount);

        uint256 newShares = psm.deposit(address(usdc), receiver1, usdcAmount);

        assertEq(newShares, usdcAmount * 1e12);

        susds.mint(user1, susdsAmount1);
        susds.approve(address(psm), susdsAmount1);

        newShares = psm.deposit(address(susds), receiver1, susdsAmount1);

        assertEq(newShares, susdsAmount1 * 125/100);

        vm.stopPrank();

        assertEq(usdc.balanceOf(pocket), usdcAmount);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(address(psm)), susdsAmount1);

        // Deposited at 1:1 conversion
        uint256 receiver1Shares = user1DepositValue;

        assertEq(psm.totalShares(),     receiver1Shares);
        assertEq(psm.shares(user1),     0);
        assertEq(psm.shares(receiver1), receiver1Shares);

        mockRateProvider.__setConversionRate(newRate);

        vm.startPrank(user2);

        susds.mint(user2, susdsAmount2);
        susds.approve(address(psm), susdsAmount2);

        assertEq(susds.allowance(user2, address(psm)), susdsAmount2);
        assertEq(susds.balanceOf(user2),               susdsAmount2);
        assertEq(susds.balanceOf(address(psm)),        susdsAmount1);

        // Receiver1 has gained from conversion change
        uint256 receiver1NewValue = user1DepositValue + susdsAmount1 * (newRate - 1.25e27) / 1e27;

        // Receiver1 has gained from conversion change
        assertApproxEqAbs(
            psm.convertToAssetValue(psm.shares(receiver1)),
            receiver1NewValue,
            1
        );

        assertEq(psm.convertToAssetValue(psm.shares(receiver2)), 0);

        assertApproxEqAbs(psm.totalAssets(), receiver1NewValue, 1);

        newShares = psm.deposit(address(susds), receiver2, susdsAmount2);

        // Using queried values here instead of derived to avoid larger errors getting introduced
        // Assertions above prove that these values are as expected.
        uint256 receiver2Shares
            = (susdsAmount2 * newRate / 1e27) * psm.totalShares() / psm.totalAssets();

        assertApproxEqAbs(newShares, receiver2Shares, 2);

        assertEq(susds.allowance(user2, address(psm)), 0);
        assertEq(susds.balanceOf(user2),               0);
        assertEq(susds.balanceOf(address(psm)),        susdsAmount1 + susdsAmount2);

        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        assertApproxEqAbs(psm.totalShares(),     receiver1Shares + receiver2Shares, 2);
        assertApproxEqAbs(psm.shares(receiver1), receiver1Shares,                   2);
        assertApproxEqAbs(psm.shares(receiver2), receiver2Shares,                   2);

        uint256 receiver2NewValue = susdsAmount2 * newRate / 1e27;

        // Rate change of up to 1000x introduces errors
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(receiver1)), receiver1NewValue, 1000);
        assertApproxEqAbs(psm.convertToAssetValue(psm.shares(receiver2)), receiver2NewValue, 1000);

        assertApproxEqAbs(psm.totalAssets(), receiver1NewValue + receiver2NewValue, 1000);
    }

}
