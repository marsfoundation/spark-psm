// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "../src/PSM3.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMWithdrawTests is PSMTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_withdraw_zeroReceiver() public {
        _deposit(address(usdc), user1, 100e6);

        vm.expectRevert("PSM3/invalid-receiver");
        psm.withdraw(address(usdc), address(0), 100e6, 0);
    }

    function test_withdraw_zeroAmount() public {
        _deposit(address(usdc), user1, 100e6);

        vm.expectRevert("PSM3/invalid-amount");
        psm.withdraw(address(usdc), receiver1, 0, 0);
    }

    function test_withdraw_notAsset0OrAsset1() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.withdraw(makeAddr("new-asset"), receiver1, 100e6, 0);
    }

    function test_withdraw_onlyDaiInPsm() public {
        _deposit(address(dai), user1, 100e18);

        assertEq(dai.balanceOf(user1),        0);
        assertEq(dai.balanceOf(receiver1),    0);
        assertEq(dai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(dai), receiver1, 100e18, 0);

        assertEq(amount, 100e18);

        assertEq(dai.balanceOf(user1),        0);
        assertEq(dai.balanceOf(receiver1),    100e18);
        assertEq(dai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlyUsdcInPsm() public {
        _deposit(address(usdc), user1, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 100e6, 0);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlySDaiInPsm() public {
        _deposit(address(sDai), user1, 80e18);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(receiver1),    0);
        assertEq(sDai.balanceOf(address(psm)), 80e18);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(sDai), receiver1, 80e18, 0);

        assertEq(amount, 80e18);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(receiver1),    80e18);
        assertEq(sDai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_usdcThenSDai() public {
        _deposit(address(usdc), user1, 100e6);
        _deposit(address(sDai), user1, 100e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(receiver1),    0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 100e6, 0);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(receiver1),    0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        amount = psm.withdraw(address(sDai), receiver1, 100e18, 0);

        assertEq(amount, 100e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(receiver1),    100e18);
        assertEq(sDai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_amountHigherThanBalanceOfAsset() public {
        _deposit(address(usdc), user1, 100e6);
        _deposit(address(sDai), user1, 100e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 125e6, 0);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 125e18);  // Only burns $100 of shares
        assertEq(psm.shares(user1), 125e18);
    }

    function test_withdraw_amountHigherThanUserShares() public {
        _deposit(address(usdc), user1, 100e6);
        _deposit(address(sDai), user1, 100e18);
        _deposit(address(usdc), user2, 200e6);

        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(receiver2),    0);
        assertEq(usdc.balanceOf(address(psm)), 300e6);

        assertEq(psm.totalShares(), 425e18);
        assertEq(psm.shares(user2), 200e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user2);
        uint256 amount = psm.withdraw(address(usdc), receiver2, 225e6, 0);

        assertEq(amount, 200e6);

        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(receiver2),    200e6);  // Gets highest amount possible
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user2), 0);  // Burns the users full amount of shares
    }

    // Adding this test to demonstrate that numbers are exact and correspond to assets deposits/withdrawals when withdrawals
    // aren't greater than the user's share balance. The next test doesn't constrain this, but there are rounding errors of
    // up to 1e12 for USDC because of the difference in asset precision. Up to 1e12 shares can be burned for 0 USDC in some
    // cases, but this is an intentional rounding error against the user.
    function testFuzz_withdraw_multiUser_noFullShareBurns(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        public
    {
        // Zero amounts revert
        depositAmount1 = _bound(depositAmount1, 1, USDC_TOKEN_MAX);
        depositAmount2 = _bound(depositAmount2, 1, USDC_TOKEN_MAX);
        depositAmount3 = _bound(depositAmount3, 1, SDAI_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, USDC_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, depositAmount2);  // User can't burn up to 1e12 shares for 0 USDC in this case
        withdrawAmount3 = _bound(withdrawAmount3, 1, SDAI_TOKEN_MAX);

        // Run with zero share tolerance because the rounding error shouldn't be introduced with the above constraints.
        _runWithdrawFuzzTests(
            0,
            depositAmount1,
            depositAmount2,
            depositAmount3,
            withdrawAmount1,
            withdrawAmount2,
            withdrawAmount3
        );
    }

    function testFuzz_withdraw_multiUser_fullShareBurns(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        public
    {
        // Zero amounts revert
        depositAmount1 = _bound(depositAmount1, 1, USDC_TOKEN_MAX);
        depositAmount2 = _bound(depositAmount2, 1, USDC_TOKEN_MAX);
        depositAmount3 = _bound(depositAmount3, 1, SDAI_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, USDC_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, USDC_TOKEN_MAX);
        withdrawAmount3 = _bound(withdrawAmount3, 1, SDAI_TOKEN_MAX);

        // Run with 1e12 share tolerance because the rounding error will be introduced with the above constraints.
        _runWithdrawFuzzTests(
            1e12,
            depositAmount1,
            depositAmount2,
            depositAmount3,
            withdrawAmount1,
            withdrawAmount2,
            withdrawAmount3
        );
    }

    // NOTE: For `assertApproxEqAbs` assertions, a difference calculation is used here instead of comparing
    // the two values because this approach inherently asserts that the shares remaining are lower than the
    // theoretical value, proving the PSM rounds against the user.
    function _runWithdrawFuzzTests(
        uint256 usdcShareTolerance,
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 depositAmount3,
        uint256 withdrawAmount1,
        uint256 withdrawAmount2,
        uint256 withdrawAmount3
    )
        internal
    {
        _deposit(address(usdc), user1, depositAmount1);
        _deposit(address(usdc), user2, depositAmount2);
        _deposit(address(sDai), user2, depositAmount3);

        uint256 totalUsdc  = depositAmount1 + depositAmount2;
        uint256 totalValue = totalUsdc * 1e12 + depositAmount3 * 125/100;

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    0);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc);

        assertEq(psm.shares(user1), depositAmount1 * 1e12);
        assertEq(psm.totalShares(), totalValue);

        uint256 expectedWithdrawnAmount1
            = _getExpectedWithdrawnAmount(usdc, user1, withdrawAmount1);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, withdrawAmount1, 0);

        assertEq(amount, expectedWithdrawnAmount1);

        _checkPsmInvariant();

        assertEq(
            usdc.balanceOf(receiver1) * 1e12 + psm.getPsmTotalValue(),
            totalValue
        );

        // NOTE: User 1 doesn't need a tolerance because their shares are 1e6 precision because they only
        //       deposited USDC. User 2 has a tolerance because they deposited sDAI which has 1e18 precision
        //       so there is a chance that the rounding will be off by up to 1e12.
        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(receiver2),    0);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - expectedWithdrawnAmount1);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);
        assertEq(psm.shares(user2), depositAmount2 * 1e12 + depositAmount3 * 125/100);  // Includes sDAI deposit
        assertEq(psm.totalShares(), totalValue - expectedWithdrawnAmount1 * 1e12);

        uint256 expectedWithdrawnAmount2
            = _getExpectedWithdrawnAmount(usdc, user2, withdrawAmount2);

        vm.prank(user2);
        amount = psm.withdraw(address(usdc), receiver2, withdrawAmount2, 0);

        assertEq(amount, expectedWithdrawnAmount2);

        _checkPsmInvariant();

        assertEq(
            (usdc.balanceOf(receiver1) + usdc.balanceOf(receiver2)) * 1e12 + psm.getPsmTotalValue(),
            totalValue
        );

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(receiver2),    expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2));

        assertEq(sDai.balanceOf(user2),        0);
        assertEq(sDai.balanceOf(receiver2),    0);
        assertEq(sDai.balanceOf(address(psm)), depositAmount3);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (expectedWithdrawnAmount2 * 1e12)) - psm.shares(user2),
            0,
            usdcShareTolerance
        );

        assertApproxEqAbs(
            (totalValue - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2) * 1e12) - psm.totalShares(),
            0,
            usdcShareTolerance
        );

        uint256 expectedWithdrawnAmount3
            = _getExpectedWithdrawnAmount(sDai, user2, withdrawAmount3);

        vm.prank(user2);
        amount = psm.withdraw(address(sDai), receiver2, withdrawAmount3, 0);

        assertApproxEqAbs(amount, expectedWithdrawnAmount3, 1);

        _checkPsmInvariant();

        assertApproxEqAbs(
            (usdc.balanceOf(receiver1) + usdc.balanceOf(receiver2)) * 1e12
                + (sDai.balanceOf(receiver2) * rateProvider.getConversionRate() / 1e27)
                + psm.getPsmTotalValue(),
            totalValue,
            1
        );

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),        0);
        assertEq(usdc.balanceOf(receiver2),    expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(address(psm)), totalUsdc - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2));

        assertApproxEqAbs(sDai.balanceOf(user2),        0,                                         0);
        assertApproxEqAbs(sDai.balanceOf(receiver2),    expectedWithdrawnAmount3,                  1);
        assertApproxEqAbs(sDai.balanceOf(address(psm)), depositAmount3 - expectedWithdrawnAmount3, 1);

        assertEq(psm.shares(user1), (depositAmount1 - expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (expectedWithdrawnAmount2 * 1e12) - (expectedWithdrawnAmount3 * 125/100)) - psm.shares(user2),
            0,
            usdcShareTolerance + 1  // 1 is added to the tolerance because of rounding error in sDAI calculations
        );

        assertApproxEqAbs(
            totalValue - (expectedWithdrawnAmount1 + expectedWithdrawnAmount2) * 1e12 - (expectedWithdrawnAmount3 * 125/100) - psm.totalShares(),
            0,
            usdcShareTolerance + 1  // 1 is added to the tolerance because of rounding error in sDAI calculations
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

    function _checkPsmInvariant() internal view {
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
    //     _deposit(address(usdc), user1, 100e6);
    //     _deposit(address(sDai), user2, 100e18);

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
    //     psm.withdraw(address(usdc), 100e18, 0);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1, 0);

    //     console2.log("First CTA", psm.convertToAssetValue(100e18));

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares, 0);

    //     console2.log("\n\n\n");

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100e18));

    //     psm.withdraw(address(sDai), 100e18 - maxUsdcShares, 0);

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
    //     psm.withdraw(address(sDai), 125e18, 0);

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
    //     _deposit(address(usdc), user1, 100_000_000e6);
    //     _deposit(address(sDai), user2, 100_000_000e18);

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
    //     psm.withdraw(address(usdc), 100_000_000e18, 0);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1, 0);

    //     console2.log("First CTA", psm.convertToAssetValue(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares, 0);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssetValue(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     maxUsdcShares = 90_000_000e18;

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100_000_000e18));

    //     psm.withdraw(address(sDai), 100_000_000e18 - maxUsdcShares, 0);

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
    //     psm.withdraw(address(sDai), 125_000_000e18, 0);

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
    //     _deposit(address(usdc), user1, 100_000_000e6);
    //     _deposit(address(sDai), user2, 100_000_000e18);

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
    //     psm.withdraw(address(usdc), 100_000_000e18, 0);

    //     // Boundary condition at 90.000001e18 shares
    //     vm.expectRevert("SafeERC20/transfer-failed");
    //     psm.withdraw(address(usdc), maxUsdcShares + 1, 0);

    //     console2.log("First CTA", psm.convertToAssetValue(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares, 0);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssetValue(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100_000_000e18));

    //     psm.withdraw(address(sDai), 100_000_000e18 - maxUsdcShares, 0);

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
    //     psm.withdraw(address(sDai), 125_000_000e18, 0);

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
    //     _deposit(address(usdc), user1, 100e6);
    //     _deposit(address(sDai), user2, 100e18);

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
    //     // psm.withdraw(address(usdc), 100e18, 0);

    //     // // Boundary condition at 90.000001e18 shares
    //     // vm.expectRevert("SafeERC20/transfer-failed");
    //     // psm.withdraw(address(usdc), maxUsdcShares + 1, 0);

    //     console2.log("First CTA", psm.convertToAssetValue(100e18));

    //     // maxUsdcShares = 89.99999e18;

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares, 0);

    //     console2.log("\n\n\n");

    //     // assertEq(sDai.balanceOf(user1),        0);
    //     // assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     // assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssetValue(100e18));

    //     // psm.withdraw(address(sDai), 100e18 - maxUsdcShares, 0);

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
    //     // psm.withdraw(address(sDai), 100e18, 0);

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
