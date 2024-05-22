// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract InflationAttackTests is PSMTestBase {

    // TODO: Decide if DAI test is needed
    function test_inflationAttack_noInitialBurnAmount() public {
        psm = new PSM(address(dai), address(usdc), address(sDai), address(rateProvider), 0);

        address firstDepositor = makeAddr("firstDepositor");
        address frontRunner    = makeAddr("frontRunner");

        // Step 1: Front runner deposits 1 sDAI to get 1 share

        // Have to use sDai because 1 USDC mints 1e12 shares
        _deposit(frontRunner, address(sDai), 1);

        assertEq(psm.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        deal(address(usdc), frontRunner, 10_000_000e6);

        vm.prank(frontRunner);
        usdc.transfer(address(psm), 10_000_000e6);

        // Highly inflated exchange rate
        assertEq(psm.convertToAssetValue(1), 10_000_000e18 + 1);

        // Step 3: First depositor deposits 20 million USDC, only gets one share because rounding
        //         error gives them 1 instead of 2 shares, worth 15m USDC

        _deposit(firstDepositor, address(usdc), 20_000_000e6);

        assertEq(psm.shares(firstDepositor), 1);

        // 1 share = 3 million USDC / 2 shares = 1.5 million USDC
        assertEq(psm.convertToAssetValue(1), 15_000_000e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(firstDepositor, address(usdc), type(uint256).max);
        _withdraw(frontRunner,    address(usdc), type(uint256).max);

        assertEq(usdc.balanceOf(address(psm)), 0);

        // Front runner profits 5m USDC, first depositor loses 5m USDC
        assertEq(usdc.balanceOf(firstDepositor), 15_000_000e6);
        assertEq(usdc.balanceOf(frontRunner),    15_000_000e6);
    }

    function test_inflationAttack_useInitialBurnAmount_firstDepositOverflowBoundary() public {
        psm = new PSM(address(dai), address(usdc), address(sDai), address(rateProvider), 1000);

        address frontRunner = makeAddr("frontRunner");

        vm.startPrank(frontRunner);
        sDai.mint(frontRunner, 800);
        sDai.approve(address(psm), 800);

        vm.expectRevert(stdError.arithmeticError);
        psm.deposit(address(sDai), 799);

        // 800 sDAI = 1000 shares
        psm.deposit(address(sDai), 800);
    }

    function test_inflationAttack_useInitialBurnAmount() public {
        psm = new PSM(address(dai), address(usdc), address(sDai), address(rateProvider), 1000);

        address firstDepositor = makeAddr("firstDepositor");
        address frontRunner    = makeAddr("frontRunner");

        // Step 1: Front runner deposits 801 sDAI to get 1 share

        // 1000 shares get burned, user is left with 1
        _deposit(frontRunner, address(sDai), 801);

        assertEq(psm.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        deal(address(usdc), frontRunner, 10_000_000e6);

        vm.prank(frontRunner);
        usdc.transfer(address(psm), 10_000_000e6);

        // Much less inflated exchange rate
        assertEq(psm.convertToAssetValue(1), 9990.009990009990009991e18);

        // Step 3: First depositor deposits 20 million USDC, only gets one share because rounding
        //         error gives them 1 instead of 2 shares, worth 15m USDC

        _deposit(firstDepositor, address(usdc), 20_000_000e6);

        assertEq(psm.shares(firstDepositor), 2001);

        // Higher amount of initial shares means lower rounding error
        assertEq(psm.convertToAssetValue(2001), 19_996_668.887408394403731513e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(firstDepositor, address(usdc), type(uint256).max);
        _withdraw(frontRunner,    address(usdc), type(uint256).max);

        // Burnt shares have a claim on these
        // TODO: Should this be an admin contract instead of address(0)?
        assertEq(usdc.balanceOf(address(psm)), 9_993_337.774818e6);

        // Front runner loses 9.99m USDC, first depositor loses 4k USDC
        assertEq(usdc.balanceOf(firstDepositor), 19_996_668.887408e6);
        assertEq(usdc.balanceOf(frontRunner),    9_993.337774e6);
    }

}
