// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMWithdrawTests is PSMTestBase {

    address user1     = makeAddr("user1");
    address user2     = makeAddr("user2");
    address receiver1 = makeAddr("receiver1");
    address receiver2 = makeAddr("receiver2");

    function test_withdraw_zeroAmount() public {
        _deposit(address(usdc), user1, 100e6);

        vm.expectRevert("PSM3/invalid-amount");
        psm.withdraw(address(usdc), receiver1, 0);
    }

    function test_withdraw_notUsdcOrUsds() public {
        vm.expectRevert("PSM3/invalid-asset");
        psm.withdraw(makeAddr("new-asset"), receiver1, 100e6);
    }

    function test_withdraw_pocketInsufficientApprovalBoundary() public {
        vm.prank(pocket);
        usdc.approve(address(psm), 100e18);

        _deposit(address(usdc), user1, 100e18 + 1);

        vm.prank(user1);
        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.withdraw(address(usdc), receiver1, 100e18 + 1);
    }

    function test_withdraw_onlyUsdsInPsm() public {
        _deposit(address(usds), user1, 100e18);

        assertEq(usds.balanceOf(user1),        0);
        assertEq(usds.balanceOf(receiver1),    0);
        assertEq(usds.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usds), receiver1, 100e18);

        assertEq(amount, 100e18);

        assertEq(usds.balanceOf(user1),        0);
        assertEq(usds.balanceOf(receiver1),    100e18);
        assertEq(usds.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlyUsdcInPsm() public {
        _deposit(address(usdc), user1, 100e6);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 0);
        assertEq(usdc.balanceOf(pocket),    100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 100e6);
        assertEq(usdc.balanceOf(pocket),    0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlyUsdcInPsm_pocketIsPsm() public {
        vm.prank(owner);
        psm.setPocket(address(psm));

        _deposit(address(usdc), user1, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(receiver1),    100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_onlySUsdsInPsm() public {
        _deposit(address(susds), user1, 80e18);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(receiver1),    0);
        assertEq(susds.balanceOf(address(psm)), 80e18);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(susds), receiver1, 80e18);

        assertEq(amount, 80e18);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(receiver1),    80e18);
        assertEq(susds.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_usdcThenSUsds() public {
        _deposit(address(usdc), user1, 100e6);
        _deposit(address(susds), user1, 100e18);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 0);
        assertEq(usdc.balanceOf(pocket),    100e6);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(receiver1),    0);
        assertEq(susds.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 100e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 100e6);
        assertEq(usdc.balanceOf(pocket),    0);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(receiver1),    0);
        assertEq(susds.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        amount = psm.withdraw(address(susds), receiver1, 100e18);

        assertEq(amount, 100e18);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 100e6);
        assertEq(usdc.balanceOf(pocket),    0);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(receiver1),    100e18);
        assertEq(susds.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_withdraw_amountHigherThanBalanceOfAsset() public {
        _deposit(address(usdc),  user1, 100e6);
        _deposit(address(susds), user1, 100e18);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 0);
        assertEq(usdc.balanceOf(pocket),    100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 225e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, 125e6);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 100e6);
        assertEq(usdc.balanceOf(pocket),    0);

        assertEq(psm.totalShares(), 125e18);  // Only burns $100 of shares
        assertEq(psm.shares(user1), 125e18);
    }

    function test_withdraw_amountHigherThanUserShares() public {
        _deposit(address(usdc),  user1, 100e6);
        _deposit(address(susds), user1, 100e18);
        _deposit(address(usdc),  user2, 200e6);

        assertEq(usdc.balanceOf(user2),     0);
        assertEq(usdc.balanceOf(receiver2), 0);
        assertEq(usdc.balanceOf(pocket),    300e6);

        assertEq(psm.totalShares(), 425e18);
        assertEq(psm.shares(user2), 200e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user2);
        uint256 amount = psm.withdraw(address(usdc), receiver2, 225e6);

        assertEq(amount, 200e6);

        assertEq(usdc.balanceOf(user2),     0);
        assertEq(usdc.balanceOf(receiver2), 200e6);  // Gets highest amount possible
        assertEq(usdc.balanceOf(pocket),    100e6);

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
        depositAmount3 = _bound(depositAmount3, 1, SUSDS_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, USDC_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, depositAmount2);  // User can't burn up to 1e12 shares for 0 USDC in this case
        withdrawAmount3 = _bound(withdrawAmount3, 1, SUSDS_TOKEN_MAX);

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
        depositAmount3 = _bound(depositAmount3, 1, SUSDS_TOKEN_MAX);

        // Zero amounts revert
        withdrawAmount1 = _bound(withdrawAmount1, 1, USDC_TOKEN_MAX);
        withdrawAmount2 = _bound(withdrawAmount2, 1, USDC_TOKEN_MAX);
        withdrawAmount3 = _bound(withdrawAmount3, 1, SUSDS_TOKEN_MAX);

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

    struct WithdrawFuzzTestVars {
        uint256 totalUsdc;
        uint256 totalValue;
        uint256 expectedWithdrawnAmount1;
        uint256 expectedWithdrawnAmount2;
        uint256 expectedWithdrawnAmount3;
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
        _deposit(address(usdc),  user1, depositAmount1);
        _deposit(address(usdc),  user2, depositAmount2);
        _deposit(address(susds), user2, depositAmount3);

        WithdrawFuzzTestVars memory vars;

        vars.totalUsdc  = depositAmount1 + depositAmount2;
        vars.totalValue = vars.totalUsdc * 1e12 + depositAmount3 * 125/100;

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), 0);
        assertEq(usdc.balanceOf(pocket),    vars.totalUsdc);

        assertEq(psm.shares(user1), depositAmount1 * 1e12);
        assertEq(psm.totalShares(), vars.totalValue);

        vars.expectedWithdrawnAmount1 = _getExpectedWithdrawnAmount(usdc, user1, withdrawAmount1);

        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), receiver1, withdrawAmount1);

        assertEq(amount, vars.expectedWithdrawnAmount1);

        _checkPsmInvariant();

        assertEq(
            usdc.balanceOf(receiver1) * 1e12 + psm.totalAssets(),
            vars.totalValue
        );

        // NOTE: User 1 doesn't need a tolerance because their shares are 1e6 precision because they only
        //       deposited USDC. User 2 has a tolerance because they deposited sUSDS which has 1e18 precision
        //       so there is a chance that the rounding will be off by up to 1e12.
        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),     0);
        assertEq(usdc.balanceOf(receiver2), 0);
        assertEq(usdc.balanceOf(pocket),    vars.totalUsdc - vars.expectedWithdrawnAmount1);

        assertEq(psm.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);
        assertEq(psm.shares(user2), depositAmount2 * 1e12 + depositAmount3 * 125/100);  // Includes sUSDS deposit
        assertEq(psm.totalShares(), vars.totalValue - vars.expectedWithdrawnAmount1 * 1e12);

        vars.expectedWithdrawnAmount2 = _getExpectedWithdrawnAmount(usdc, user2, withdrawAmount2);

        vm.prank(user2);
        amount = psm.withdraw(address(usdc), receiver2, withdrawAmount2);

        assertEq(amount, vars.expectedWithdrawnAmount2);

        _checkPsmInvariant();

        assertEq(
            (usdc.balanceOf(receiver1) + usdc.balanceOf(receiver2)) * 1e12 + psm.totalAssets(),
            vars.totalValue
        );

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),     0);
        assertEq(usdc.balanceOf(receiver2), vars.expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(pocket),    vars.totalUsdc - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2));

        assertEq(susds.balanceOf(user2),        0);
        assertEq(susds.balanceOf(receiver2),    0);
        assertEq(susds.balanceOf(address(psm)), depositAmount3);

        assertEq(psm.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (vars.expectedWithdrawnAmount2 * 1e12)) - psm.shares(user2),
            0,
            usdcShareTolerance
        );

        assertApproxEqAbs(
            (vars.totalValue - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2) * 1e12) - psm.totalShares(),
            0,
            usdcShareTolerance
        );

        vars.expectedWithdrawnAmount3 = _getExpectedWithdrawnAmount(susds, user2, withdrawAmount3);

        vm.prank(user2);
        amount = psm.withdraw(address(susds), receiver2, withdrawAmount3);

        assertApproxEqAbs(amount, vars.expectedWithdrawnAmount3, 1);

        _checkPsmInvariant();

        assertApproxEqAbs(
            (usdc.balanceOf(receiver1) + usdc.balanceOf(receiver2)) * 1e12
                + (susds.balanceOf(receiver2) * rateProvider.getConversionRate() / 1e27)
                + psm.totalAssets(),
            vars.totalValue,
            1
        );

        assertEq(usdc.balanceOf(user1),     0);
        assertEq(usdc.balanceOf(receiver1), vars.expectedWithdrawnAmount1);
        assertEq(usdc.balanceOf(user2),     0);
        assertEq(usdc.balanceOf(receiver2), vars.expectedWithdrawnAmount2);
        assertEq(usdc.balanceOf(pocket),    vars.totalUsdc - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2));

        assertApproxEqAbs(susds.balanceOf(user2),        0,                                              0);
        assertApproxEqAbs(susds.balanceOf(receiver2),    vars.expectedWithdrawnAmount3,                  1);
        assertApproxEqAbs(susds.balanceOf(address(psm)), depositAmount3 - vars.expectedWithdrawnAmount3, 1);

        assertEq(psm.shares(user1), (depositAmount1 - vars.expectedWithdrawnAmount1) * 1e12);

        assertApproxEqAbs(
            ((depositAmount2 * 1e12) + (depositAmount3 * 125/100) - (vars.expectedWithdrawnAmount2 * 1e12) - (vars.expectedWithdrawnAmount3 * 125/100)) - psm.shares(user2),
            0,
            usdcShareTolerance + 1  // 1 is added to the tolerance because of rounding error in sUSDS calculations
        );

        assertApproxEqAbs(
            vars.totalValue - (vars.expectedWithdrawnAmount1 + vars.expectedWithdrawnAmount2) * 1e12 - (vars.expectedWithdrawnAmount3 * 125/100) - psm.totalShares(),
            0,
            usdcShareTolerance + 1  // 1 is added to the tolerance because of rounding error in sUSDS calculations
        );
    }

    function test_withdraw_changeConversionRate() public {
        _deposit(address(usdc),  user1, 100e6);
        _deposit(address(susds), user2, 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        mockRateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 sUSDS value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(psm.convertToShares(1e18), 0.9e18);

        assertEq(usdc.balanceOf(user1),  0);
        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 100e18);
        assertEq(psm.shares(user2), 125e18);

        // NOTE: Users shares have more value than the balance of USDC now
        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), user1, type(uint256).max);

        assertEq(amount, 100e6);

        assertEq(usdc.balanceOf(user1),  100e6);
        assertEq(usdc.balanceOf(pocket), 0);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(user2),        0);
        assertEq(susds.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 135e18);
        assertEq(psm.shares(user1), 10e18);  // Burn 90 shares to get 100 USDC
        assertEq(psm.shares(user2), 125e18);

        vm.prank(user1);
        amount = psm.withdraw(address(susds), user1, type(uint256).max);

        uint256 user1SUsds = uint256(10e18) * 1e18 / 0.9e18 * 1e27 / 1.5e27;

        assertEq(amount,     user1SUsds);
        assertEq(user1SUsds, 7.407407407407407407e18);

        assertEq(susds.balanceOf(user1),        user1SUsds);
        assertEq(susds.balanceOf(user2),        0);
        assertEq(susds.balanceOf(address(psm)), 100e18 - user1SUsds);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 125e18);

        vm.prank(user2);
        amount = psm.withdraw(address(susds), user2, type(uint256).max);

        assertEq(amount, 100e18 - user1SUsds - 1);  // Remaining funds in PSM (rounding)

        assertEq(susds.balanceOf(user1),        user1SUsds);
        assertEq(susds.balanceOf(user2),        100e18 - user1SUsds - 1);  // Rounding
        assertEq(susds.balanceOf(address(psm)), 1);                       // Rounding

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        uint256 user1ResultingValue = usdc.balanceOf(user1) * 1e12 + susds.balanceOf(user1) * 150/100;
        uint256 user2ResultingValue = susds.balanceOf(user2) * 150/100;  // Use 1.5 conversion rate

        assertEq(user1ResultingValue, 111.111111111111111110e18);
        assertEq(user2ResultingValue, 138.888888888888888888e18);

        assertEq(user1ResultingValue + user2ResultingValue, 249.999999999999999998e18);

        // Value gains are the same for both users
        assertEq((user1ResultingValue - 100e18) * 1e18 / 100e18, 0.111111111111111111e18);
        assertEq((user2ResultingValue - 125e18) * 1e18 / 125e18, 0.111111111111111111e18);
    }

    function testFuzz_withdraw_changeConversionRate(
        uint256 usdcAmount,
        uint256 susdsAmount,
        uint256 conversionRate
    )
        public
    {
        // Use higher lower bounds to get returns at the end to be more accurate
        // Always increase exchange rate so accrual of value can be checked.
        // Since rounding is against user if it stays the same the value can decrease and
        // the check will underflow
        usdcAmount     = _bound(usdcAmount,     1e6,     USDC_TOKEN_MAX);
        susdsAmount    = _bound(susdsAmount,    1e18,    SUSDS_TOKEN_MAX);
        conversionRate = _bound(conversionRate, 1.26e27, 1000e27);

        _deposit(address(usdc), user1, usdcAmount);
        _deposit(address(susds), user2, susdsAmount);

        mockRateProvider.__setConversionRate(conversionRate);

        uint256 user1Shares = usdcAmount * 1e12;
        uint256 user2Shares = susdsAmount * 125/100;
        uint256 totalShares = user1Shares + user2Shares;
        uint256 totalValue  = usdcAmount * 1e12 + susdsAmount * conversionRate / 1e27;

        assertEq(psm.totalAssets(), totalValue);

        assertEq(psm.totalShares(), totalShares);
        assertEq(psm.shares(user1), user1Shares);
        assertEq(psm.shares(user2), user2Shares);

        assertEq(usdc.balanceOf(user1),  0);
        assertEq(usdc.balanceOf(pocket), usdcAmount);

        // NOTE: Users shares have more value than the balance of USDC now
        vm.prank(user1);
        uint256 amount = psm.withdraw(address(usdc), user1, type(uint256).max);

        assertEq(amount, usdcAmount);  // Withdraws all USDC since shares are worth more

        assertEq(usdc.balanceOf(user1),  usdcAmount);
        assertEq(usdc.balanceOf(pocket), 0);

        assertEq(susds.balanceOf(user1),        0);
        assertEq(susds.balanceOf(user2),        0);
        assertEq(susds.balanceOf(address(psm)), susdsAmount);

        uint256 expectedUser1SharesBurned = usdcAmount * 1e12 * totalShares / totalValue;

        assertApproxEqAbs(psm.totalShares(), totalShares - expectedUser1SharesBurned, 2);
        assertApproxEqAbs(psm.shares(user1), user1Shares - expectedUser1SharesBurned, 2);
        assertApproxEqAbs(psm.shares(user2), user2Shares,                             0);

        vm.prank(user1);
        amount = psm.withdraw(address(susds), user1, type(uint256).max);

        {
            // User1s remaining shares are used
            uint256 user1SUsds = (user1Shares - expectedUser1SharesBurned)
                * totalValue
                / totalShares
                * 1e27
                / conversionRate;

            assertApproxEqAbs(susds.balanceOf(user1),        user1SUsds,               2);
            assertApproxEqAbs(susds.balanceOf(user2),        0,                        0);
            assertApproxEqAbs(susds.balanceOf(address(psm)), susdsAmount - user1SUsds, 2);

            vm.prank(user2);
            amount = psm.withdraw(address(susds), user2, type(uint256).max);

            assertApproxEqAbs(amount, susdsAmount - user1SUsds, 2);

            assertApproxEqAbs(susds.balanceOf(user1),        user1SUsds,               2);
            assertApproxEqAbs(susds.balanceOf(user2),        susdsAmount - user1SUsds, 2);
            assertApproxEqAbs(susds.balanceOf(address(psm)), 0,                        2);
        }

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        uint256 user1ResultingValue
            = usdc.balanceOf(user1) * 1e12 + susds.balanceOf(user1) * conversionRate / 1e27;

        uint256 user2ResultingValue = susds.balanceOf(user2) * conversionRate / 1e27;  // Use 1.5 conversion rate

        assertLe(psm.totalAssets(), 1000);

        // Equal to starting value
        assertApproxEqAbs(user1ResultingValue + user2ResultingValue, totalValue - psm.totalAssets(), 2);

        // Value gains are the same for both users, accurate to 0.02%
        assertApproxEqRel(
            (user1ResultingValue - (usdcAmount * 1e12))    * 1e18 / (usdcAmount * 1e12),
            (user2ResultingValue - (susdsAmount * 125/100)) * 1e18 / (susdsAmount * 125/100),
            0.0021e18
        );
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _checkPsmInvariant() internal view {
        uint256 totalSharesValue = psm.convertToAssetValue(psm.totalShares());
        uint256 totalAssetsValue =
            susds.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27
            + usdc.balanceOf(pocket) * 1e12;

        assertApproxEqAbs(totalSharesValue, totalAssetsValue, 1);
    }

    function _getExpectedWithdrawnAmount(MockERC20 asset, address user, uint256 amount)
        internal view returns (uint256 withdrawAmount)
    {
        address custodian = address(asset) == address(usdc) ? pocket : address(psm);

        uint256 balance    = asset.balanceOf(custodian);
        uint256 userAssets = psm.convertToAssets(address(asset), psm.shares(user));

        // Return the min of assets, balance, and amount
        withdrawAmount = userAssets < balance        ? userAssets : balance;
        withdrawAmount = amount     < withdrawAmount ? amount     : withdrawAmount;
    }

}
