// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { LPHandler } from "test/invariant/handlers/HandlerBase.sol";

contract PSMInvariantTests is PSMTestBase {

    LPHandler public lpHandler;

    function setUp() public override {
        super.setUp();

        lpHandler = new LPHandler(psm, dai, usdc, sDai, 3);

        targetContract(address(lpHandler));
    }

    function invariant_A() public {
        assertEq(true, true);
        console.log("count", lpHandler.count());
    }
}
