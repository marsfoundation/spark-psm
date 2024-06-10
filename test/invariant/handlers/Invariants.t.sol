// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM3 } from "src/PSM3.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMInvariantTests is PSMTestBase {

    function setUp() public override {
        super.setUp();
    }

    function invariant_A() public {
        assertEq(true, true);
    }
}
