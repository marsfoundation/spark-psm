// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract InflationAttackTests is PSMTestBase {

    function test_inflationAttack_noInitialBurnAmount() public {
        psm = new PSM(address(usdc), address(sDai), address(rateProvider), 0);

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
}
