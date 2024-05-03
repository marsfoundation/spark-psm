// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConversionTests is PSMTestBase {

    function test_convertToShares() public {
        // usdc.mint(address(psm), 100e6);
        // sDai.mint(address(psm), 100e18);

        // uint256 shares = psm.convertToShares(100e6, 80e18);

        // assertEq(shares, 80e18);
    }
}
