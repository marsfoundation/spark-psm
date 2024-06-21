// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { LpHandler }      from "test/invariant/handlers/LpHandler.sol";
import { SwapperHandler } from "test/invariant/handlers/SwapperHandler.sol";

contract PSMInvariantTests is PSMTestBase {

    LpHandler      public lpHandler;
    SwapperHandler public swapperHandler;

    address BURN_ADDRESS = makeAddr("burn-address");

    // NOTE [CRITICAL]: All invariant tests are operating under the assumption that the initial seed
    //                  deposit of 1e18 shares has been made. This is a key requirement and
    //                  assumption for all invariant tests.
    function setUp() public override {
        super.setUp();

        // Seed the pool with 1e18 shares (1e18 of value)
        _deposit(address(dai), BURN_ADDRESS, 1e18);

        lpHandler      = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler = new SwapperHandler(psm, dai, usdc, sDai, 3);

        // TODO: Add rate updates
        rateProvider.__setConversionRate(1.25e27);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
    }

    function invariant_A() public view {
        assertEq(
            psm.shares(address(lpHandler.lps(0))) +
            psm.shares(address(lpHandler.lps(1))) +
            psm.shares(address(lpHandler.lps(2))) +
            1e18,  // Seed amount
            psm.totalShares()
        );
    }

    function invariant_B() public view {
        assertApproxEqAbs(
            psm.getPsmTotalValue(),
            psm.convertToAssetValue(psm.totalShares()),
            2
        );
    }

    function invariant_C() public view {
        assertApproxEqAbs(
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(0)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(1)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(2)))) +
            psm.convertToAssetValue(1e18),  // Seed amount
            psm.getPsmTotalValue(),
            4
        );
    }

    function invariant_logs() public view {
        console.log("depositCount    ", lpHandler.depositCount());
        console.log("withdrawCount   ", lpHandler.withdrawCount());
        console.log("swapCount       ", swapperHandler.swapCount());
        console.log("zeroBalanceCount", swapperHandler.zeroBalanceCount());
        console.log(
            "sum             ",
            lpHandler.depositCount() +
            lpHandler.withdrawCount() +
            swapperHandler.swapCount() +
            swapperHandler.zeroBalanceCount()
        );
    }

}
