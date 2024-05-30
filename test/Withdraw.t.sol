// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMWithdrawTests is PSMTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_withdraw_notAsset0OrAsset1() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.withdraw(makeAddr("new-asset"), 100e6);
    }

    // TODO: Add balance/approve failure tests

    function test_withdraw_onlyUsdcInPsm() public {
        _deposit(user1, address(usdc), 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), 100e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlySDaiInPsm() public {
        _deposit(user1, address(sDai), 80e18);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(address(psm)), 80e18);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(sDai), 80e18);

        assertEq(amount, 80e18);

        assertEq(sDai.balanceOf(user1),        80e18);
        assertEq(sDai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_usdcThenSDai() public {
        _deposit(user1, address(usdc), 100e6);
        _deposit(user1, address(sDai), 100e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), 100e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        amount = psm.withdraw(address(sDai), 100e18);

        assertEq(amount, 100e18);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        100e18);
        assertEq(sDai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_amountHigherThanBalanceOfAsset() public {
        _deposit(user1, address(usdc), 100e6);
        _deposit(user1, address(sDai), 100e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), 125e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 125e18);  // Only burns $100 of shares
        assertEq(psm.shares(user1), 125e18);
    }

    function test_withdraw_amountHigherThanUserShares() public {
        _deposit(user1, address(usdc), 100e6);
        _deposit(user1, address(sDai), 100e18);
        _deposit(user2, address(usdc), 200e6);

        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(address(psm)), 300e6);

        assertEq(psm.totalShares(), 425e18);
        assertEq(psm.shares(user2), 200e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user2);
        uint256 amount = psm.withdraw(address(usdc), 225e6);

        assertEq(amount, 200e6);

        assertEq(usdc.balanceOf(user2),        200e6);  // Gets highest amount possible
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user2), 0);  // Burns the users full amount of shares
    }

    function testFuzz_withdraw_multiUser(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        public
    {
        // NOTE: Not covering zero cases, 1e-2 at 1e6 used as min for now so exact values can
        //       be asserted
        depositAmount1 = bound(depositAmount1, 0, USDC_TOKEN_MAX);
        depositAmount2 = bound(depositAmount2, 0, USDC_TOKEN_MAX);
        depositAmount3 = bound(depositAmount3, 0, SDAI_TOKEN_MAX);

        withdrawAmount1 = bound(withdrawAmount1, 0, USDC_TOKEN_MAX);
        withdrawAmount2 = bound(withdrawAmount2, 0, USDC_TOKEN_MAX);
        withdrawAmount3 = bound(withdrawAmount3, 0, SDAI_TOKEN_MAX);

        _deposit(user1, address(usdc), depositAmount1);
        _deposit(user2, address(usdc), depositAmount2);
        _deposit(user2, address(sDai), depositAmount3);

        uint256 totalUsdc  = depositAmount1 + depositAmount2;
        uint256 totalValue = totalUsdc * 1e12 + depositAmount3 * 125/100;

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc);

        assertEq(psm.shares(user1), depositAmount1 * 1e12);
        assertEq(psm.totalShares(), totalValue);

        uint256 expectedWithdrawnAmount1
            = _getExpectedWithdrawnAmount(usdc, user1, withdrawAmount1);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), withdrawAmount1);

        assertEq(amount, expectedWithdrawnAmount1);

        _checkPsmInvariant();

        assertEq(
            usdc.balanceOf(user1) * 1e12 + psm.getPsmTotalValue(),
            totalValue
        );

        assertEq(usdc.balanceOf(user1),        expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - expectedWithdrawnAmount1);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);
        assertEq(psm.shares(user2), depositAmount2 * 1e12 + depositAmount3 * 125/100);  // Includes sDAI deposit
        assertEq(psm.totalShares(), totalValue - expectedWithdrawnAmount1 * 1e12);

        uint256 expectedWithdrawnAmount2
            = _getExpectedWithdrawnAmount(usdc, user2, withdrawAmount2);

        vm.prank(user2);
        amount = psm.withdraw(address(usdc), withdrawAmount2);

        assertEq(amount, expectedWithdrawnAmount2);

        _checkPsmInvariant();

        assertEq(
            (usdc.balanceOf(user1) + usdc.balanceOf(user2)) * 1e12 + psm.getPsmTotalValue(),
            totalValue
        );

        assertEq(usdc.balanceOf(user1),        expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2));

        assertEq(sDai.balanceOf(user2),        0);
        assertEq(sDai.balanceOf(address(psm)), depositAmount3);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);

        assertEq(
            psm.shares(user2),
            (depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (expectedWithdrawnAmount2 * 1e12)
        );

        assertEq(psm.totalShares(), totalValue - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2) * 1e12);

        uint256 expectedWithdrawnAmount3
            = _getExpectedWithdrawnAmount(sDai, user2, withdrawAmount3);

        vm.prank(user2);
        amount = psm.withdraw(address(sDai), withdrawAmount3);

        assertApproxEqAbs(amount, expectedWithdrawnAmount3, 1);

        _checkPsmInvariant();

        assertApproxEqAbs(
            (usdc.balanceOf(user1) + usdc.balanceOf(user2)) * 1e12
                + (sDai.balanceOf(user2) * rateProvider.getConversionRate() / 1e27)
                + psm.getPsmTotalValue(),
            totalValue,
            1
        );

        assertEq(usdc.balanceOf(user1),        expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2));

        assertApproxEqAbs(sDai.balanceOf(user2),        expectedWithdrawnAmount3,                  1);
        assertApproxEqAbs(sDai.balanceOf(address(psm)), depositAmount3 - expectedWithdrawnAmount3, 1);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            psm.shares(user2),
            (depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (expectedWithdrawnAmount2 * 1e12) - (expectedWithdrawnAmount3 * 125/100),
            1
        );

        assertApproxEqAbs(
            psm.totalShares(),
            totalValue - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2) * 1e12 - (expectedWithdrawnAmount3 * 125/100),
            1
        );

        // -- TODO: Get these to work, rounding assertions proving always rounding down

        // assertLe(sDai.balanceOf(user2),        expectedWithdrawnAmount3);
        // assertGe(sDai.balanceOf(address(psm)), depositAmount3 - expectedWithdrawnAmount3);

        // assertLe(
        //     psm.shares(user2),
        //     (depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (expectedWithdrawnAmount2 * 1e12) - (expectedWithdrawnAmount3 * 125/100)
        // );

        // assertLe(
        //     psm.totalShares(),
        //     totalValue - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2) * 1e12 - (expectedWithdrawnAmount3 * 125/100)
        // );
    }

    function _checkPsmInvariant() internal {
        uint256 totalSharesValue = psm.convertToAssetValue(psm.totalShares());
        uint256 totalAssetsValue =
            sDai.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27
            + usdc.balanceOf(address(psm)) * 1e12;

        assertApproxEqAbs(totalSharesValue, totalAssetsValue, 1);
    }

    function _getExpectedWithdrawnAmount(MockERC20 asset, address user, uint256 amount)
        internal view returns (uint256 withdrawAmount)
    {
        // TODO: See if convertToAssets can be used
        uint256 balance    = asset.balanceOf(address(psm));
        uint256 userAssets = psm.convertToAssetValue(psm.shares(user));

        if (address(asset) == address(usdc)) {
            userAssets /= 1e12;
        }

        if (address(asset) == address(sDai)) {
            userAssets = userAssets * 1e27 / rateProvider.getConversionRate();
        }

        // Return the min of assets, balance, and amount
        withdrawAmount = userAssets < balance        ? userAssets : balance;
        withdrawAmount = amount     < withdrawAmount ? amount     : withdrawAmount;
    }

    // function test_withdraw_changeConversionRate_smallBalances_nonRoundingCode() public {
    //     _deposit(user1, address(usdc), 100e6);
    //     _deposit(user2, address(sDai), 100e18);

    //     assertEq(psm.totalShares(), 225e18);
    //     assertEq(psm.shares(user1), 100e18);
    //     assertEq(psm.shares(user2), 125e18);

    //     assertEq(psm.convertToShares(1e18), 1e18);

    //     rateProvider.__setConversionRate(1.5e27);

    //     // Total shares / (100 USDC + 150 sDAI value)
    //     uint256 expectedConversionRate = 225 * 1e18 / 250;

    //     assertEq(expectedConversionRate, 0.9e18);

    //     assertEq(psm.convertToShares(1e18), 0.9e18);

    //     assertEq(usdc.balanceOf(user1),        0);
    //     assertEq(usdc.balanceOf(address(psm)), 100e6);

    //     assertEq(psm.totalShares(), 225e18);
    //     assertEq(psm.shares(user1), 100e18);
    //     assertEq(psm.shares(user2), 125e18);

    //     // Solving for `a` to get a result of 100.000001e6 USDC to transfer out
    //     // a * (250/225) / 1e12 = 100.000001e6
    //     // a = 100.000001e6 * 1e12 / (250/225)
    //     // a = 100.000001e18 * (225/250)
    //     // Subtract 1 to get the amount that will succeed
    //     uint256 maxUsdcShares = 100.000001e18 * 0.9 - 1;

    //     assertEq(maxUsdcShares, 90.0000009e18 - 1);

    //     // NOTE: Users shares have more value than the balance of USDC now
    //     vm.startPrank(user1);

    //     // Original full balance reverts
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), 100e18);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1);

    //     console2.log("First CTA", psm.convertToAssetValue(100e18));

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100e18));

    //     psm.withdraw(address(sDai), 100e18 - maxUsdcShares);

    //     uint256 sDaiUser1Balance = 7.407406790123452675e18;

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100e18 - sDaiUser1Balance);

    //     assertEq(psm.totalShares(), 125e18);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 125e18);

    //     vm.stopPrank();
    //     vm.startPrank(user2);

    //     console2.log("Third CTA", psm.convertToAssetValue(100e18));

    //     // Withdraw shares originally worth $100 to compare yield with user1
    //     psm.withdraw(address(sDai), 125e18);

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        100e18 - sDaiUser1Balance - 1);
    //     assertEq(sDai.balanceOf(address(psm)), 1);

    //     assertEq(psm.totalShares(), 0);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 0);

    //     uint256 user1ResultingValue = usdc.balanceOf(user1) * 1e12 + sDai.balanceOf(user1) * 150/100;
    //     uint256 user2ResultingValue = sDai.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

    //     assertEq(user1ResultingValue, 111.111110185185179012e18);
    //     assertEq(user2ResultingValue, 138.888889814814820986e18);

    //     assertEq(user1ResultingValue + user2ResultingValue, 249.999999999999999998e18);

    //     // User1 gets a 0.000015% lower percentage yield than user2
    //     assertEq((user1ResultingValue - 100e18) * 1e18 / 100e18, 0.111111101851851790e18);
    //     assertEq((user2ResultingValue - 125e18) * 1e18 / 125e18, 0.111111118518518567e18);
    // }

    // function test_withdraw_changeConversionRate_bigBalances_roundingCode() public {
    //     _deposit(user1, address(usdc), 100_000_000e6);
    //     _deposit(user2, address(sDai), 100_000_000e18);

    //     assertEq(psm.totalShares(), 225_000_000e18);
    //     assertEq(psm.shares(user1), 100_000_000e18);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     assertEq(psm.convertToShares(1e18), 1e18);

    //     rateProvider.__setConversionRate(1.5e27);

    //     // Total shares / (100 USDC + 150 sDAI value)
    //     uint256 expectedConversionRate = 225 * 1e18 / 250;

    //     assertEq(expectedConversionRate, 0.9e18);

    //     assertEq(psm.convertToShares(1e18), 0.9e18);

    //     assertEq(usdc.balanceOf(user1),        0);
    //     assertEq(usdc.balanceOf(address(psm)), 100_000_000e6);

    //     assertEq(psm.totalShares(), 225_000_000e18);
    //     assertEq(psm.shares(user1), 100_000_000e18);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     // Solving for `a` to get a result of 100.000001e6 USDC to transfer out
    //     // a * (250/225) / 1e12 = 100.000001e6
    //     // a = 100.000001e6 * 1e12 / (250/225)
    //     // a = 100.000001e18 * (225/250)
    //     // Subtract 1 to get the amount that will succeed
    //     uint256 maxUsdcShares = 100_000_000.000001e18 * 0.9 - 1;

    //     assertEq(maxUsdcShares, 90_000_000.0000009e18 - 1);

    //     // NOTE: Users shares have more value than the balance of USDC now
    //     vm.startPrank(user1);

    //     // Original full balance reverts
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), 100_000_000e18);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1);

    //     console2.log("First CTA", psm.convertToAssetValue(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssetValue(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     maxUsdcShares = 90_000_000e18;

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100_000_000e18));

    //     psm.withdraw(address(sDai), 100_000_000e18 - maxUsdcShares);

    //     uint256 sDaiUser1Balance = 7_407_407.407407407407407407e18;

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18 - sDaiUser1Balance);

    //     assertEq(psm.totalShares(), 125_000_000e18);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     vm.stopPrank();
    //     vm.startPrank(user2);

    //     console2.log("Third CTA", psm.convertToAssetValue(100e18));

    //     // Withdraw shares originally worth $100 to compare yield with user1
    //     psm.withdraw(address(sDai), 125_000_000e18);

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        100_000_000e18 - sDaiUser1Balance - 1);
    //     assertEq(sDai.balanceOf(address(psm)), 1);

    //     assertEq(psm.totalShares(), 0);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 0);

    //     uint256 user1ResultingValue = usdc.balanceOf(user1) * 1e12 + sDai.balanceOf(user1) * 150/100;
    //     uint256 user2ResultingValue = sDai.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

    //     console.log("\n\n FINAL RESULTS");
    //     console.log("user1SDai", sDai.balanceOf(user1));

    //     assertEq(user1ResultingValue, 111_111_111.111111111111111110e18);
    //     assertEq(user2ResultingValue, 138_888_888.888888888888888888e18);

    //     assertEq(user1ResultingValue + user2ResultingValue, 249_999_999.999999999999999998e18);

    //     assertEq((user1ResultingValue - 100_000_000e18) * 1e18 / 100_000_000e18, 0.111111111111111111e18);
    //     assertEq((user2ResultingValue - 125_000_000e18) * 1e18 / 125_000_000e18, 0.111111111111111111e18);
    // }

    // function test_withdraw_changeConversionRate_bigBalances_nonRoundingCode() public {
    //     _deposit(user1, address(usdc), 100_000_000e6);
    //     _deposit(user2, address(sDai), 100_000_000e18);

    //     assertEq(psm.totalShares(), 225_000_000e18);
    //     assertEq(psm.shares(user1), 100_000_000e18);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     assertEq(psm.convertToShares(1e18), 1e18);

    //     rateProvider.__setConversionRate(1.5e27);

    //     // Total shares / (100 USDC + 150 sDAI value)
    //     uint256 expectedConversionRate = 225 * 1e18 / 250;

    //     assertEq(expectedConversionRate, 0.9e18);

    //     assertEq(psm.convertToShares(1e18), 0.9e18);

    //     assertEq(usdc.balanceOf(user1),        0);
    //     assertEq(usdc.balanceOf(address(psm)), 100_000_000e6);

    //     assertEq(psm.totalShares(), 225_000_000e18);
    //     assertEq(psm.shares(user1), 100_000_000e18);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     // Solving for `a` to get a result of 100.000001e6 USDC to transfer out
    //     // a * (250/225) / 1e12 = 100.000001e6
    //     // a = 100.000001e6 * 1e12 / (250/225)
    //     // a = 100.000001e18 * (225/250)
    //     // Subtract 1 to get the amount that will succeed
    //     uint256 maxUsdcShares = 100_000_000.000001e18 * 0.9 - 1;

    //     assertEq(maxUsdcShares, 90_000_000.0000009e18 - 1);

    //     // NOTE: Users shares have more value than the balance of USDC now
    //     vm.startPrank(user1);

    //     // Original full balance reverts
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), 100_000_000e18);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1);

    //     console2.log("First CTA", psm.convertToAssetValue(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssetValue(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100_000_000e18));

    //     psm.withdraw(address(sDai), 100_000_000e18 - maxUsdcShares);

    //     uint256 sDaiUser1Balance = 7_407_407.407406790123456790e18;

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18 - sDaiUser1Balance);

    //     assertEq(psm.totalShares(), 125_000_000e18);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     vm.stopPrank();
    //     vm.startPrank(user2);

    //     console2.log("Third CTA", psm.convertToAssetValue(100e18));

    //     // Withdraw shares originally worth $100 to compare yield with user1
    //     psm.withdraw(address(sDai), 125_000_000e18);

    //     assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(user2),        100_000_000e18 - sDaiUser1Balance);
    //     assertEq(sDai.balanceOf(address(psm)), 0);

    //     assertEq(psm.totalShares(), 0);
    //     assertEq(psm.shares(user1), 0);
    //     assertEq(psm.shares(user2), 0);

    //     uint256 user1ResultingValue = usdc.balanceOf(user1) * 1e12 + sDai.balanceOf(user1) * 150/100;
    //     uint256 user2ResultingValue = sDai.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

    //     console.log("\n\n FINAL RESULTS");
    //     console.log("user1SDai", sDai.balanceOf(user1));

    //     assertEq(user1ResultingValue, 111_111_111.111110185185185185e18);
    //     assertEq(user2ResultingValue, 138_888_888.888889814814814815e18);

    //     assertEq(user1ResultingValue + user2ResultingValue, 250_000_000e18);

    //     // User1 gets a 0.000000000015% lower percentage yield than user2 because the shares
    //     // that could've been used to withdraw sDAI with burned on the withdrawal.
    //     assertEq((user1ResultingValue - 100_000_000e18) * 1e18 / 100_000_000e18, 0.111111111111101851e18);
    //     assertEq((user2ResultingValue - 125_000_000e18) * 1e18 / 125_000_000e18, 0.111111111111118518e18);
    // }

    // function test_withdraw_2() public {
    //     _deposit(user1, address(usdc), 100e6);
    //     _deposit(user2, address(sDai), 100e18);

    //     assertEq(psm.totalShares(), 225e18);
    //     assertEq(psm.shares(user1), 100e18);
    //     assertEq(psm.shares(user2), 125e18);

    //     assertEq(psm.convertToShares(1e18), 1e18);

    //     rateProvider.__setConversionRate(1.5e27);

    //     // Total shares / (100 USDC + 150 sDAI value)
    //     uint256 expectedConversionRate = 225 * 1e18 / 250;

    //     assertEq(expectedConversionRate, 0.9e18);

    //     assertEq(psm.convertToShares(1e18), 0.9e18);

    //     assertEq(usdc.balanceOf(user1),        0);
    //     assertEq(usdc.balanceOf(address(psm)), 100e6);

    //     assertEq(psm.totalShares(), 225e18);
    //     assertEq(psm.shares(user1), 100e18);
    //     assertEq(psm.shares(user2), 125e18);

    //     // Solving for `a` to get a result of 100.000001e6 USDC to transfer out
    //     // a * (250/225) / 1e12 = 100.000001e6
    //     // a = 100.000001e6 * 1e12 / (250/225)
    //     // a = 100.000001e18 * (225/250)
    //     // Subtract 1 to get the amount that will succeed
    //     uint256 maxUsdcShares = 100.000001e18 * 0.9 - 1;

    //     assertEq(maxUsdcShares, 90.0000009e18 - 1);

    //     // // NOTE: Users shares have more value than the balance of USDC now
    //     vm.startPrank(user1);

    //     // // Original full balance reverts
    //     // vm.expectRevert("SafeERC20/transfer-failed");
    //     // psm.withdraw(address(usdc), 100e18);

    //     // // Boundary condition at 90.000001e18 shares
    //     // vm.expectRevert("SafeERC20/transfer-failed");
    //     // psm.withdraw(address(usdc), maxUsdcShares + 1);

    //     console2.log("First CTA", psm.convertToAssetValue(100e18));

    //     // maxUsdcShares = 89.99999e18;

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     // assertEq(sDai.balanceOf(user1),        0);
    //     // assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     // assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100e18));

    //     // psm.withdraw(address(sDai), 100e18 - maxUsdcShares);

    //     // uint256 sDaiUser1Balance = 7.407406790123452675e18;

    //     // assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     // assertEq(sDai.balanceOf(user2),        0);
    //     // assertEq(sDai.balanceOf(address(psm)), 100e18 - sDaiUser1Balance);

    //     // assertEq(psm.totalShares(), 125e18);
    //     // assertEq(psm.shares(user1), 0);
    //     // assertEq(psm.shares(user2), 125e18);

    //     // vm.stopPrank();
    //     // vm.startPrank(user2);

    //     // console2.log("Third CTA", psm.convertToAssetValue(100e18));

    //     // // Withdraw shares originally worth $100 to compare yield with user1
    //     // psm.withdraw(address(sDai), 100e18);

    //     // // assertEq(sDai.balanceOf(user1),        sDaiUser1Balance);
    //     // // assertEq(sDai.balanceOf(user2),        100e18 - sDaiUser1Balance - 1);
    //     // // assertEq(sDai.balanceOf(address(psm)), 1);

    //     // // assertEq(psm.totalShares(), 0);
    //     // // assertEq(psm.shares(user1), 0);
    //     // // assertEq(psm.shares(user2), 0);

    //     // uint256 user1ResultingValue = usdc.balanceOf(user1) * 1e12 + sDai.balanceOf(user1);
    //     // uint256 user2ResultingValue = sDai.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

    //     // assertEq(user1ResultingValue, 107.407406790123452675e18);
    //     // assertEq(user2ResultingValue, 111.111111851851856788e18);

    //     // assertEq(user1ResultingValue + user2ResultingValue, 250e18);

    //     // assertEq((user1ResultingValue - 100e18) * 1e18 / 100e18, 0.074074067901234526e18);
    //     // assertEq((user2ResultingValue - 125e18) * 1e18 / 125e18, 0.111111118518518567e18);
    // }

}
