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

    function test_withdraw_multiUser_changeExchangeRate() public {
        _deposit(user1, address(usdc), 100e6);
        _deposit(user2, address(sDai), 100e18);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 100e18);
        assertEq(psm.shares(user2), 125e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        rateProvider.__setConversionRate(1.5e27);

        // Total shares / (100 USDC + 150 sDAI value)
        uint256 expectedConversionRate = 225 * 1e18 / 250;

        assertEq(expectedConversionRate, 0.9e18);

        assertEq(psm.convertToShares(1e18), 0.9e18);

        assertEq(usdc.balanceOf(user1),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user1), 100e18);
        assertEq(psm.shares(user2), 125e18);

        // TODO: Address
        // vm.prank(user1);
        // psm.withdraw(address(usdc), 100e18);

        // assertEq(psm.convertToShares(1e18), 0.9e18);

        // assertEq(usdc.balanceOf(user1),        0);
        // assertEq(usdc.balanceOf(address(psm)), 0);

        // assertEq(psm.totalShares(), 225e18);
        // assertEq(psm.shares(user1), 100e18);
        // assertEq(psm.shares(user2), 125e18);

        // TODO: Address
        // vm.prank(user1);
        // psm.withdraw(address(sDai), 125e18);

        // assertEq(usdc.balanceOf(user1),        100e6);
        // assertEq(usdc.balanceOf(address(psm)), 0);

        // assertEq(sDai.balanceOf(user1),        100e18);
        // assertEq(sDai.balanceOf(address(psm)), 0);

        // assertEq(psm.totalShares(), 0);
        // assertEq(psm.shares(user1), 0);

        // assertEq(psm.convertToShares(1e18), 1e18);
    }

}
