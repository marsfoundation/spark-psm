// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSwapAssetZeroToOneTests is PSMTestBase {

    address public buyer = makeAddr("buyer");

    function setUp() public override {
        super.setUp();

        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swapAssetZeroToOne_amountZero() public {
        vm.expectRevert("PSM/invalid-amountIn");
        psm.swapAssetZeroToOne(0, 0);
    }

    function test_swapAssetZeroToOne_minAmountOutBoundary() public {
        usdc.mint(buyer, 100e6);

        vm.startPrank(buyer);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountOut = psm.previewSwapAssetZeroToOne(100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("PSM/invalid-amountOut");
        psm.swapAssetZeroToOne(100e6, 80e18 + 1);

        psm.swapAssetZeroToOne(100e6, 80e18);
    }

    function test_swapAssetZeroToOne_insufficientApproveBoundary() public {
        usdc.mint(buyer, 100e6);

        vm.startPrank(buyer);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapAssetZeroToOne(100e6, 80e18);

        usdc.approve(address(psm), 100e6);

        psm.swapAssetZeroToOne(100e6, 80e18);
    }

    function test_swapAssetZeroToOne_insufficientUserBalanceBoundary() public {
        usdc.mint(buyer, 100e6 - 1);

        vm.startPrank(buyer);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapAssetZeroToOne(100e6, 80e18);

        usdc.mint(buyer, 1);

        psm.swapAssetZeroToOne(100e6, 80e18);
    }

    function test_swapAssetZeroToOne_insufficientPsmBalanceBoundary() public {
        usdc.mint(buyer, 125e6 + 1);

        vm.startPrank(buyer);

        usdc.approve(address(psm), 125e6 + 1);

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapAssetZeroToOne(125e6 + 1, 100e18);

        psm.swapAssetZeroToOne(125e6, 100e18);
    }

    function test_swapAssetZeroToOne() public assertAtomicPsmValueDoesNotChange {
        usdc.mint(buyer, 100e6);

        vm.startPrank(buyer);

        usdc.approve(address(psm), 100e6);

        assertEq(usdc.allowance(buyer, address(psm)), 100e6);

        assertEq(sDai.balanceOf(buyer),        0);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(usdc.balanceOf(buyer),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        psm.swapAssetZeroToOne(100e6, 80e18);

        assertEq(usdc.allowance(buyer, address(psm)), 0);

        assertEq(sDai.balanceOf(buyer),        80e18);
        assertEq(sDai.balanceOf(address(psm)), 20e18);

        assertEq(usdc.balanceOf(buyer),        0);
        assertEq(usdc.balanceOf(address(psm)), 200e6);
    }

}

contract PSMSwapAssetOneToZeroTests is PSMTestBase {

    address public buyer = makeAddr("buyer");

    function setUp() public override {
        super.setUp();

        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swapAssetOneToZero_amountZero() public {
        vm.expectRevert("PSM/invalid-amountIn");
        psm.swapAssetOneToZero(0, 0);
    }

    function test_swapAssetOneToZero_minAmountOutBoundary() public {
        sDai.mint(buyer, 80e18);

        vm.startPrank(buyer);

        sDai.approve(address(psm), 80e18);

        uint256 expectedAmountOut = psm.previewSwapAssetOneToZero(80e18);

        assertEq(expectedAmountOut, 100e6);

        vm.expectRevert("PSM/invalid-amountOut");
        psm.swapAssetOneToZero(80e18, 100e6 + 1);

        psm.swapAssetOneToZero(80e18, 100e6);
    }

    function test_swapAssetOneToZero_insufficientApproveBoundary() public {
        sDai.mint(buyer, 80e18);

        vm.startPrank(buyer);

        sDai.approve(address(psm), 80e18 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapAssetOneToZero(80e18, 100e6);

        sDai.approve(address(psm), 80e18);

        psm.swapAssetOneToZero(80e18, 100e6);
    }

    function test_swapAssetOneToZero_insufficientUserBalanceBoundary() public {
        sDai.mint(buyer, 80e18 - 1);

        vm.startPrank(buyer);

        sDai.approve(address(psm), 80e18);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swapAssetOneToZero(80e18, 100e6);

        sDai.mint(buyer, 1);

        psm.swapAssetOneToZero(80e18, 100e6);
    }

    function test_swapAssetOneToZero_insufficientPsmBalanceBoundary() public {
        // Prove that values yield balance boundary
        // 0.8e12 * 1.25 = 1e12 == 1-e6 in 18 decimal precision
        assertEq(psm.previewSwapAssetOneToZero(80e18 + 0.8e12),     100e6 + 1);
        assertEq(psm.previewSwapAssetOneToZero(80e18 + 0.8e12 - 1), 100e6);

        sDai.mint(buyer, 80e18 + 0.8e12);

        vm.startPrank(buyer);

        sDai.approve(address(psm), 80e18 + 0.8e12);

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swapAssetOneToZero(80e18 + 0.8e12, 100e6);

        psm.swapAssetOneToZero(80e18 + 0.8e12 - 1, 100e6);
    }

    function test_swapAssetOneToZero() public assertAtomicPsmValueDoesNotChange {
        sDai.mint(buyer, 80e18);

        vm.startPrank(buyer);

        sDai.approve(address(psm), 80e18);

        assertEq(sDai.allowance(buyer, address(psm)), 80e18);

        assertEq(sDai.balanceOf(buyer),        80e18);
        assertEq(sDai.balanceOf(address(psm)), 100e18);

        assertEq(usdc.balanceOf(buyer),        0);
        assertEq(usdc.balanceOf(address(psm)), 100e6);

        psm.swapAssetOneToZero(80e18, 100e6);

        assertEq(usdc.allowance(buyer, address(psm)), 0);

        assertEq(sDai.balanceOf(buyer),        0);
        assertEq(sDai.balanceOf(address(psm)), 180e18);

        assertEq(usdc.balanceOf(buyer),        100e6);
        assertEq(usdc.balanceOf(address(psm)), 0);
    }

}
