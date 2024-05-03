// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMDepositTests is PSMTestBase {

    address user = makeAddr("user");

    function test_deposit_firstDepositUsdc() public {
        usdc.mint(user, 100e6);

        vm.startPrank(user);

        usdc.approve(address(psm), 100e6);

        assertEq(usdc.allowance(user, address(psm)), 100e6);
        assertEq(usdc.balanceOf(user),               100e6);
        assertEq(usdc.balanceOf(address(psm)),       0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user),  0);

        assertEq(psm.convertToShares(1e18), 1e18);

        psm.deposit(address(usdc), 100e6);

        assertEq(usdc.allowance(user, address(psm)), 0);
        assertEq(usdc.balanceOf(user),               0);
        assertEq(usdc.balanceOf(address(psm)),       100e6);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user),  100e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_firstDepositSDai() public {
        sDai.mint(user, 100e18);

        vm.startPrank(user);

        sDai.approve(address(psm), 100e18);

        assertEq(sDai.allowance(user, address(psm)), 100e18);
        assertEq(sDai.balanceOf(user),               100e18);
        assertEq(sDai.balanceOf(address(psm)),       0);

        assertEq(psm.totalShares(), 0);
        assertEq(psm.shares(user),  0);

        assertEq(psm.convertToShares(1e18), 1e18);

        psm.deposit(address(sDai), 100e18);

        assertEq(sDai.allowance(user, address(psm)), 0);
        assertEq(sDai.balanceOf(user),               0);
        assertEq(sDai.balanceOf(address(psm)),       100e18);

        assertEq(psm.totalShares(), 125e18);
        assertEq(psm.shares(user),  125e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function test_deposit_usdcThenSDai() public {
        usdc.mint(user, 100e6);

        vm.startPrank(user);

        usdc.approve(address(psm), 100e6);

        psm.deposit(address(usdc), 100e6);

        sDai.mint(user, 100e18);
        sDai.approve(address(psm), 100e18);

        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.allowance(user, address(psm)), 100e18);
        assertEq(sDai.balanceOf(user),               100e18);
        assertEq(sDai.balanceOf(address(psm)),       0);

        assertEq(psm.totalShares(), 100e18);
        assertEq(psm.shares(user),  100e18);

        assertEq(psm.convertToShares(1e18), 1e18);

        psm.deposit(address(sDai), 100e18);

        assertEq(usdc.balanceOf(address(psm)), 100e6);

        assertEq(sDai.allowance(user, address(psm)), 0);
        assertEq(sDai.balanceOf(user),               0);
        assertEq(sDai.balanceOf(address(psm)),       100e18);

        assertEq(psm.totalShares(), 225e18);
        assertEq(psm.shares(user),  225e18);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

    function testFuzz_deposit_usdcThenSDai(uint256 usdcAmount, uint256 sDaiAmount) public {
        usdcAmount = _bound(usdcAmount, 0, USDC_TOKEN_MAX);
        sDaiAmount = _bound(sDaiAmount, 0, SDAI_TOKEN_MAX);

        usdc.mint(user, usdcAmount);

        vm.startPrank(user);

        usdc.approve(address(psm), usdcAmount);

        psm.deposit(address(usdc), usdcAmount);

        sDai.mint(user, sDaiAmount);
        sDai.approve(address(psm), sDaiAmount);

        assertEq(usdc.balanceOf(address(psm)), usdcAmount);

        assertEq(sDai.allowance(user, address(psm)), sDaiAmount);
        assertEq(sDai.balanceOf(user),               sDaiAmount);
        assertEq(sDai.balanceOf(address(psm)),       0);

        assertEq(psm.totalShares(), usdcAmount * 1e12);
        assertEq(psm.shares(user),  usdcAmount * 1e12);

        assertEq(psm.convertToShares(1e18), 1e18);

        psm.deposit(address(sDai), sDaiAmount);

        assertEq(usdc.balanceOf(address(psm)), usdcAmount);

        assertEq(sDai.allowance(user, address(psm)), 0);
        assertEq(sDai.balanceOf(user),               0);
        assertEq(sDai.balanceOf(address(psm)),       sDaiAmount);

        assertEq(psm.totalShares(), usdcAmount * 1e12 + sDaiAmount * 125/100);
        assertEq(psm.shares(user),  usdcAmount * 1e12 + sDaiAmount * 125/100);

        assertEq(psm.convertToShares(1e18), 1e18);
    }

}
