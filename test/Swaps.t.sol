// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { MockERC20, PSMTestBase } from "test/PSMTestBase.sol";

contract PSMSwapFailureTests is PSMTestBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();

        // Needed for boundary success conditions
        usdc.mint(address(psm), 100e6);
        sDai.mint(address(psm), 100e18);
    }

    function test_swap_amountZero() public {
        vm.expectRevert("PSM/invalid-amountIn");
        psm.swap(address(usdc), address(sDai), 0, 0, receiver);
    }

    function test_swap_receiverZero() public {
        vm.expectRevert("PSM/invalid-receiver");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, address(0));
    }

    function test_swap_invalid_assetIn() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.swap(makeAddr("other-token"), address(sDai), 100e6, 80e18, receiver);
    }

    function test_swap_invalid_assetOut() public {
        vm.expectRevert("PSM/invalid-asset");
        psm.swap(address(usdc), makeAddr("other-token"), 100e6, 80e18, receiver);
    }

    function test_swap_minAmountOutBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        uint256 expectedAmountOut = psm.previewSwap(address(usdc), address(sDai), 100e6);

        assertEq(expectedAmountOut, 80e18);

        vm.expectRevert("PSM/amountOut-too-low");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18 + 1, receiver);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver);
    }

    function test_swap_insufficientApproveBoundary() public {
        usdc.mint(swapper, 100e6);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6 - 1);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver);

        usdc.approve(address(psm), 100e6);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver);
    }

    function test_swap_insufficientUserBalanceBoundary() public {
        usdc.mint(swapper, 100e6 - 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 100e6);

        vm.expectRevert("SafeERC20/transfer-from-failed");
        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver);

        usdc.mint(swapper, 1);

        psm.swap(address(usdc), address(sDai), 100e6, 80e18, receiver);
    }

    function test_swap_insufficientPsmBalanceBoundary() public {
        usdc.mint(swapper, 125e6 + 1);

        vm.startPrank(swapper);

        usdc.approve(address(psm), 125e6 + 1);

        uint256 expectedAmountOut = psm.previewSwap(address(usdc), address(sDai), 125e6 + 1);

        assertEq(expectedAmountOut, 100.0000008e18);  // More than balance of sDAI

        vm.expectRevert("SafeERC20/transfer-failed");
        psm.swap(address(usdc), address(sDai), 125e6 + 1, 100e18, receiver);

        psm.swap(address(usdc), address(sDai), 125e6, 100e18, receiver);
    }

}

contract PSMSuccessTestsBase is PSMTestBase {

    function setUp() public override {
        super.setUp();

        dai.mint(address(psm),  1_000_000e18);
        usdc.mint(address(psm), 1_000_000e6);
        sDai.mint(address(psm), 1_000_000e18);
    }

    function _swapTest(
        MockERC20 assetIn,
        MockERC20 assetOut,
        uint256 amountIn,
        uint256 amountOut,
        address swapper,
        address receiver
    ) internal {
        uint256 psmAssetInBalance  = 1_000_000 * 10 ** assetIn.decimals();
        uint256 psmAssetOutBalance = 1_000_000 * 10 ** assetOut.decimals();

        assetIn.mint(swapper, amountIn);

        vm.startPrank(swapper);

        assetIn.approve(address(psm), amountIn);

        assertEq(assetIn.allowance(swapper, address(psm)), amountIn);

        assertEq(assetIn.balanceOf(swapper),      amountIn);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance);

        assertEq(assetOut.balanceOf(receiver),     0);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance);

        psm.swap(address(assetIn), address(assetOut), amountIn, amountOut, receiver);

        assertEq(assetIn.allowance(swapper, address(psm)), 0);

        assertEq(assetIn.balanceOf(swapper),      0);
        assertEq(assetIn.balanceOf(address(psm)), psmAssetInBalance + amountIn);

        assertEq(assetOut.balanceOf(receiver),     amountOut);
        assertEq(assetOut.balanceOf(address(psm)), psmAssetOutBalance - amountOut);
    }

}

contract PSMSwapTests is PSMSuccessTestsBase {

    address public swapper  = makeAddr("swapper");
    address public receiver = makeAddr("receiver");

    // DAI assetIn tests

    function test_swap_daiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, usdc, 100e18, 100e6, swapper, swapper);
    }

    function test_swap_daiToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, sDai, 100e18, 80e18, swapper, swapper);
    }

    function test_swap_daiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, usdc, 100e18, 100e6, swapper, receiver);
    }

    function test_swap_daiToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(dai, sDai, 100e18, 80e18, swapper, receiver);
    }

    // USDC assetIn tests

    function test_swap_usdcToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, dai, 100e6, 100e18, swapper, swapper);
    }

    function test_swap_usdcToSDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, sDai, 100e6, 80e18, swapper, swapper);
    }

    function test_swap_usdcToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, dai, 100e6, 100e18, swapper, receiver);
    }

    function test_swap_usdcToSDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(usdc, sDai, 100e6, 80e18, swapper, receiver);
    }

    // sDai assetIn tests

    function test_swap_sDaiToDai_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, dai, 100e18, 125e18, swapper, swapper);
    }

    function test_swap_sDaiToUsdc_sameReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, usdc, 100e18, 125e6, swapper, swapper);
    }

    function test_swap_sDaiToDai_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, dai, 100e18, 125e18, swapper, receiver);
    }

    function test_swap_sDaiToUsdc_differentReceiver() public assertAtomicPsmValueDoesNotChange {
        _swapTest(sDai, usdc, 100e18, 125e6, swapper, receiver);
    }



    // function test_swapAssetZeroToOne_differentReceiver() public assertAtomicPsmValueDoesNotChange {
    //     usdc.mint(buyer, 100e6);

    //     vm.startPrank(buyer);

    //     usdc.approve(address(psm), 100e6);

    //     assertEq(usdc.allowance(buyer, address(psm)), 100e6);

    //     assertEq(sDai.balanceOf(buyer),        0);
    //     assertEq(sDai.balanceOf(receiver),     0);
    //     assertEq(sDai.balanceOf(address(psm)), 100e18);

    //     assertEq(usdc.balanceOf(buyer),        100e6);
    //     assertEq(usdc.balanceOf(receiver),     0);
    //     assertEq(usdc.balanceOf(address(psm)), 100e6);

    //     psm.swapAssetZeroToOne(100e6, 80e18, receiver);

    //     assertEq(usdc.allowance(buyer, address(psm)), 0);

    //     assertEq(sDai.balanceOf(buyer),        0);
    //     assertEq(sDai.balanceOf(receiver),     80e18);
    //     assertEq(sDai.balanceOf(address(psm)), 20e18);

    //     assertEq(usdc.balanceOf(buyer),        0);
    //     assertEq(usdc.balanceOf(receiver),     0);
    //     assertEq(usdc.balanceOf(address(psm)), 200e6);
    // }

}

// contract PSMSwapAssetOneToZeroTests is PSMTestBase {

//     address public buyer    = makeAddr("buyer");
//     address public receiver = makeAddr("receiver");

//     function setUp() public override {
//         super.setUp();

//         usdc.mint(address(psm), 100e6);
//         sDai.mint(address(psm), 100e18);
//     }

//     function test_swapAssetOneToZero_amountZero() public {
//         vm.expectRevert("PSM/invalid-amountIn");
//         psm.swapAssetOneToZero(0, 0, receiver);
//     }

//     function test_swapAssetZeroToOne_receiverZero() public {
//         vm.expectRevert("PSM/invalid-receiver");
//         psm.swapAssetOneToZero(100e6, 80e18, address(0));
//     }

//     function test_swapAssetOneToZero_minAmountOutBoundary() public {
//         sDai.mint(buyer, 80e18);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18);

//         uint256 expectedAmountOut = psm.previewSwapAssetOneToZero(80e18);

//         assertEq(expectedAmountOut, 100e6);

//         vm.expectRevert("PSM/amountOut-too-low");
//         psm.swapAssetOneToZero(80e18, 100e6 + 1, receiver);

//         psm.swapAssetOneToZero(80e18, 100e6, receiver);
//     }

//     function test_swapAssetOneToZero_insufficientApproveBoundary() public {
//         sDai.mint(buyer, 80e18);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18 - 1);

//         vm.expectRevert("SafeERC20/transfer-from-failed");
//         psm.swapAssetOneToZero(80e18, 100e6, receiver);

//         sDai.approve(address(psm), 80e18);

//         psm.swapAssetOneToZero(80e18, 100e6, receiver);
//     }

//     function test_swapAssetOneToZero_insufficientUserBalanceBoundary() public {
//         sDai.mint(buyer, 80e18 - 1);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18);

//         vm.expectRevert("SafeERC20/transfer-from-failed");
//         psm.swapAssetOneToZero(80e18, 100e6, receiver);

//         sDai.mint(buyer, 1);

//         psm.swapAssetOneToZero(80e18, 100e6, receiver);
//     }

//     function test_swapAssetOneToZero_insufficientPsmBalanceBoundary() public {
//         // Prove that values yield balance boundary
//         // 0.8e12 * 1.25 = 1e12 == 1-e6 in 18 decimal precision
//         assertEq(psm.previewSwapAssetOneToZero(80e18 + 0.8e12),     100e6 + 1);
//         assertEq(psm.previewSwapAssetOneToZero(80e18 + 0.8e12 - 1), 100e6);

//         sDai.mint(buyer, 80e18 + 0.8e12);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18 + 0.8e12);

//         vm.expectRevert("SafeERC20/transfer-failed");
//         psm.swapAssetOneToZero(80e18 + 0.8e12, 100e6, receiver);

//         psm.swapAssetOneToZero(80e18 + 0.8e12 - 1, 100e6, receiver);
//     }

//     function test_swapAssetOneToZero_sameReceiver() public assertAtomicPsmValueDoesNotChange {
//         sDai.mint(buyer, 80e18);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18);

//         assertEq(sDai.allowance(buyer, address(psm)), 80e18);

//         assertEq(sDai.balanceOf(buyer),        80e18);
//         assertEq(sDai.balanceOf(address(psm)), 100e18);

//         assertEq(usdc.balanceOf(buyer),        0);
//         assertEq(usdc.balanceOf(address(psm)), 100e6);

//         psm.swapAssetOneToZero(80e18, 100e6, buyer);

//         assertEq(usdc.allowance(buyer, address(psm)), 0);

//         assertEq(sDai.balanceOf(buyer),        0);
//         assertEq(sDai.balanceOf(address(psm)), 180e18);

//         assertEq(usdc.balanceOf(buyer),        100e6);
//         assertEq(usdc.balanceOf(address(psm)), 0);
//     }

//     function test_swapAssetOneToZero_differentReceiver() public assertAtomicPsmValueDoesNotChange {
//         sDai.mint(buyer, 80e18);

//         vm.startPrank(buyer);

//         sDai.approve(address(psm), 80e18);

//         assertEq(sDai.allowance(buyer, address(psm)), 80e18);

//         assertEq(sDai.balanceOf(buyer),        80e18);
//         assertEq(sDai.balanceOf(receiver),     0);
//         assertEq(sDai.balanceOf(address(psm)), 100e18);

//         assertEq(usdc.balanceOf(buyer),        0);
//         assertEq(usdc.balanceOf(receiver),     0);
//         assertEq(usdc.balanceOf(address(psm)), 100e6);

//         psm.swapAssetOneToZero(80e18, 100e6, receiver);

//         assertEq(usdc.allowance(buyer, address(psm)), 0);

//         assertEq(sDai.balanceOf(buyer),        0);
//         assertEq(sDai.balanceOf(receiver),     0);
//         assertEq(sDai.balanceOf(address(psm)), 180e18);

//         assertEq(usdc.balanceOf(buyer),        0);
//         assertEq(usdc.balanceOf(receiver),     100e6);
//         assertEq(usdc.balanceOf(address(psm)), 0);
//     }

// }
