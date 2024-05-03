// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMConversionTests is PSMTestBase {

    function testFuzz_convertToShares_noValue(uint256 amount) public view {
        assertEq(psm.convertToShares(amount), amount);
    }

    // TODO: Fix
    function skip_test_convertToShares_deposits() public {
        usdc.mint(address(this), 100e6);
        usdc.approve(address(psm), 100e6);

        psm.deposit(address(usdc), 100e6);

        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(2), 2);
        assertEq(psm.convertToShares(3), 3);

        assertEq(psm.convertToShares(1e18), 1e18);
        assertEq(psm.convertToShares(2e18), 2e18);
        assertEq(psm.convertToShares(3e18), 3e18);

        sDai.mint(address(this), 100e18);
        sDai.approve(address(psm), 100e18);

        psm.deposit(address(sDai), 100e18);

        assertEq(psm.convertToShares(1), 1);
        assertEq(psm.convertToShares(4), 4);
        assertEq(psm.convertToShares(8), 9);

        assertEq(psm.convertToShares(1e18), 1.125e18);
        assertEq(psm.convertToShares(4e18), 4.5e18);
        assertEq(psm.convertToShares(8e18), 9e18);

        // Mint into psm without increasing shares
        sDai.mint(address(psm), 100e18);
    }

    function testFuzz_convertToShares(uint256 usdcAmount, uint256 sDaiAmount) public {
        usdcAmount = _bound(usdcAmount, 0, USDC_TOKEN_MAX);
        sDaiAmount = _bound(sDaiAmount, 0, SDAI_TOKEN_MAX);

        usdc.mint(address(this), usdcAmount);

    }
}
