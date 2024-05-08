// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMWithdrawTests is PSMTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_withdraw_notAsset0OrAsset1() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.withdraw(address(0), 100e6);
    }

    // TODO: Add balance/approve failure tests

    function test_withdraw_onlyUsdcInPsm() public {
        _deposit(user1, address(usdc), 100e6);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user1), 100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        // NOTE: Using shares here so 1e18 denomination is used
        vm.prank(user1);
        psm.withdraw(address(usdc), 100e18);

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
        psm.withdraw(address(sDai), 100e18);

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
        psm.withdraw(address(usdc), 100e18);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user1), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        vm.prank(user1);
        psm.withdraw(address(sDai), 125e18);

        assertEq(usdc.balanceOf(user1),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);

        assertEq(sDai.balanceOf(user1),        100e18);
        assertEq(sDai.balanceOf(address(psm)), 0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    // function test_withdraw_changeExchangeRate_smallBalances_nonRoundingCode() public {
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

    //     console2.log("First CTA", psm.convertToAssets(100e18));

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssets(100e18));

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

    //     console2.log("Third CTA", psm.convertToAssets(100e18));

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

    // function test_withdraw_changeExchangeRate_bigBalances_roundingCode() public {
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

    //     console2.log("First CTA", psm.convertToAssets(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssets(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     maxUsdcShares = 90_000_000e18;

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssets(100_000_000e18));

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

    //     console2.log("Third CTA", psm.convertToAssets(100e18));

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

    // function test_withdraw_changeExchangeRate_bigBalances_nonRoundingCode() public {
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

    //     console2.log("First CTA", psm.convertToAssets(100_000_000e18));

    //     // Rounds down here and transfers 100_000_000e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     console2.log("maxUsdcShares value", psm.convertToAssets(maxUsdcShares));

    //     assertEq(sDai.balanceOf(user1),        0);
    //     assertEq(sDai.balanceOf(address(psm)), 100_000_000e18);

    //     assertEq(psm.totalShares(), 225_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user1), 100_000_000e18 - maxUsdcShares);
    //     assertEq(psm.shares(user2), 125_000_000e18);

    //     console2.log("Second CTA", psm.convertToAssets(100_000_000e18));

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

    //     console2.log("Third CTA", psm.convertToAssets(100e18));

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

    //     console2.log("First CTA", psm.convertToAssets(100e18));

    //     // maxUsdcShares = 89.99999e18;

    //     // Rounds down here and transfers 100e6 USDC
    //     psm.withdraw(address(usdc), maxUsdcShares);

    //     console2.log("\n\n\n");

    //     // assertEq(sDai.balanceOf(user1),        0);
    //     // assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     // assertEq(psm.totalShares(), 225e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user1), 100e18 - maxUsdcShares);
    //     // assertEq(psm.shares(user2), 125e18);

    //     console2.log("Second CTA", psm.convertToAssets(100e18));

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

    //     // console2.log("Third CTA", psm.convertToAssets(100e18));

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
