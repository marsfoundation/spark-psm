// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract InflationAttackTests is PSMTestBase {

    // TODO: Add DOS attack test outlined here: https://github.com/marsfoundation/spark-psm/pull/2#pullrequestreview-2085880206

    address firstDepositor = makeAddr("firstDepositor");
    address frontRunner    = makeAddr("frontRunner");
    address deployer       = makeAddr("deployer");

    function setUp() public override {
        super.setUp();
        psm = new PSM3(address(dai), address(usdc), address(sDai), address(rateProvider));
    }

    function test_inflationAttack_noInitialDeposit_sDai() public {
        // Step 1: Front runner deposits 1 sDAI to get 1 share

        // Have to use sDai because 1 USDC mints 1e12 shares
        _deposit(address(sDai), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_noInitialDeposit_dai() public {
        // Step 1: Front runner deposits 1 sDAI to get 1 share

        // Have to use DAI because 1 USDC mints 1e12 shares
        _deposit(address(dai), frontRunner, 1);

        _runInflationAttack_noInitialDepositTest();
    }

    function test_inflationAttack_useInitialDeposit_sDai() public {
        _deposit(address(sDai), address(deployer), 0.8e18);  // 1e18 shares

        // Step 1: Front runner deposits sDAI to get 1 share

        // User tries to do the same attack, depositing one sDAI for 1 share
        _deposit(address(sDai), frontRunner, 1);

        assertEq(psm.shares(frontRunner), 1);

        _runInflationAttack_useInitialDepositTest();
    }

    function test_inflationAttack_useInitialDeposit_dai() public {
        _deposit(address(dai), address(deployer), 1e18);  // 1e18 shares

        // Step 1: Front runner deposits dai to get 1 share

        // User tries to do the same attack, depositing one sDAI for 1 share
        _deposit(address(dai), frontRunner, 1);

        assertEq(psm.shares(frontRunner), 1);

        _runInflationAttack_useInitialDepositTest();
    }

    function _runInflationAttack_noInitialDepositTest() internal {
        assertEq(psm.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        deal(address(usdc), frontRunner, 10_000_000e6);

        assertEq(psm.convertToAssetValue(1), 1);

        vm.prank(frontRunner);
        usdc.transfer(address(psm), 10_000_000e6);

        // Highly inflated exchange rate
        assertEq(psm.convertToAssetValue(1), 10_000_000e18 + 1);

        // Step 3: First depositor deposits 20 million USDC, only gets one share because rounding
        //         error gives them 1 instead of 2 shares, worth 15m USDC

        _deposit(address(usdc), firstDepositor, 20_000_000e6);

        assertEq(psm.shares(firstDepositor), 1);

        // 1 share = 3 million USDC / 2 shares = 1.5 million USDC
        assertEq(psm.convertToAssetValue(1), 15_000_000e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(address(usdc), firstDepositor, type(uint256).max);
        _withdraw(address(usdc), frontRunner,    type(uint256).max);

        assertEq(usdc.balanceOf(address(psm)), 0);

        // Front runner profits 5m USDC, first depositor loses 5m USDC
        assertEq(usdc.balanceOf(firstDepositor), 15_000_000e6);
        assertEq(usdc.balanceOf(frontRunner),    15_000_000e6);
    }

    function _runInflationAttack_useInitialDepositTest() internal {
        assertEq(psm.shares(frontRunner), 1);

        // Step 2: Front runner transfers 10m USDC to inflate the exchange rate to 1:(10m + 1)

        assertEq(psm.convertToAssetValue(1), 1);

        deal(address(usdc), frontRunner, 10_000_000e6);

        vm.prank(frontRunner);
        usdc.transfer(address(psm), 10_000_000e6);

        // Still inflated, but all value is transferred to existing holder, deployer
        assertEq(psm.convertToAssetValue(1), 0.00000000001e18);

        // Step 3: First depositor deposits 20 million USDC, this time rounding is not an issue
        //         so value reflected is much more accurate

        _deposit(address(usdc), firstDepositor, 20_000_000e6);

        assertEq(psm.shares(firstDepositor), 1.999999800000020001e18);

        // Higher amount of initial shares means lower rounding error
        assertEq(psm.convertToAssetValue(1.999999800000020001e18), 19_999_999.999999999996673334e18);

        // Step 4: Both users withdraw the max amount of funds they can

        _withdraw(address(usdc), firstDepositor, type(uint256).max);
        _withdraw(address(usdc), frontRunner,    type(uint256).max);
        _withdraw(address(usdc), deployer,       type(uint256).max);

        // Front runner loses full 10m USDC to the deployer that had all shares at the beginning, first depositor loses nothing (1e-6 USDC)
        assertEq(usdc.balanceOf(firstDepositor), 19_999_999.999999e6);
        assertEq(usdc.balanceOf(frontRunner),    0);
        assertEq(usdc.balanceOf(deployer),       10_000_000.000001e6);
    }

}
