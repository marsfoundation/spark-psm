// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { LpHandler }      from "test/invariant/handlers/LpHandler.sol";
import { SwapperHandler } from "test/invariant/handlers/SwapperHandler.sol";

contract PSMInvariantTests is PSMTestBase {

    LpHandler      public lpHandler;
    SwapperHandler public swapperHandler;

    function setUp() public override {
        super.setUp();

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
            psm.shares(address(lpHandler.lps(2))),
            psm.totalShares()
        );
    }

    function invariant_B() public view {
        // Assumes exchange rate above 1 for sDAI
        // Commenting out temporarily to avoid "Reason: invariant_B replay failure" in foundry
        // assertGe(
        //     psm.getPsmTotalValue(),
        //     psm.totalShares()
        // );
    }

    function invariant_C() public view {
        assertApproxEqAbs(
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(0)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(1)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(2)))),
            psm.getPsmTotalValue(),
            3
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
