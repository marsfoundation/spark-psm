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

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
    }

    function invariant_A() public {
        assertEq(
            psm.shares(address(lpHandler.lps(0))) +
            psm.shares(address(lpHandler.lps(1))) +
            psm.shares(address(lpHandler.lps(2))),
            psm.totalShares()
        );
    }

    function invariant_logs() public {
        console.log("count1", lpHandler.count());
        console.log("count2", lpHandler.withdrawCount());
        console.log("count3", swapperHandler.count());

        console.log("lp1Shares", psm.shares(address(lpHandler.lps(0))));
        console.log("lp2Shares", psm.shares(address(lpHandler.lps(1))));
        console.log("lp3Shares", psm.shares(address(lpHandler.lps(2))));
    }
}
