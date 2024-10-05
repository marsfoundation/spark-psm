// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract InflationAttackTests is PSMTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function test_dos_sendFundsBeforeFirstDeposit() public {
        // Attack pool sending funds in before the first deposit
        usdc.mint(address(this), 100e6);
        usdc.transfer(pocket, 100e6);

        assertEq(usdc.balanceOf(pocket), 100e6);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        _deposit(address(usdc), address(user1), 1_000_000e6);

        // Since exchange rate is zero, convertToShares returns 1m * 0 / 100e6
        // because totalValue is not zero so it enters that if statement.
        // This results in the funds going in the pool with no way for the user
        // to recover them.
        assertEq(usdc.balanceOf(pocket), 1_000_100e6);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);

        // This issue is not related to the first deposit only because totalShares cannot
        // get above zero.
        _deposit(address(usdc), address(user2), 1_000_000e6);

        assertEq(usdc.balanceOf(pocket), 2_000_100e6);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user1), 0);
        assertEq(psm.shares(user2), 0);
    }

}
