// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSM } from "../src/PSM.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { MockRateProvider } from "./mocks/MockRateProvider.sol";

contract PSMTestBase is Test {

    PSM public psm;

    // NOTE: Using sDAI and USDC as example assets
    MockERC20 public sDai;
    MockERC20 public usdc;

    MockRateProvider public rateProvider;

    function setUp() public virtual {
        sDai = new MockERC20("sDai",  "sDai",  18);
        usdc = new MockERC20("usdc", "usdc", 6);

        rateProvider = new MockRateProvider();

        // NOTE: Using 1.25 for easy two way conversions
        rateProvider.__setConversionRate(1.25e27);

        psm = new PSM(address(usdc), address(sDai), address(rateProvider));
    }

    function _getPsmValue() internal view returns (uint256) {
        return (sDai.balanceOf(address(psm)) * rateProvider.getConversionRate() / 1e27)
            + usdc.balanceOf(address(psm)) * 1e12;
    }

    modifier assertAtomicPsmValueDoesNotChange {
        uint256 beforeValue = _getPsmValue();
        _;
        assertEq(_getPsmValue(), beforeValue);
    }

}

contract PSMConstructorTests is PSMTestBase {

    function test_constructor_invalidAsset0() public {
        vm.expectRevert("PSM/invalid-asset0");
        new PSM(address(0), address(sDai), address(rateProvider));
    }

    function test_constructor_invalidAsset1() public {
        vm.expectRevert("PSM/invalid-asset1");
        new PSM(address(usdc), address(0), address(rateProvider));
    }

    function test_constructor_invalidRateProvider() public {
        vm.expectRevert("PSM/invalid-rateProvider");
        new PSM(address(sDai), address(usdc), address(0));
    }

    function test_constructor() public {
        // Deploy new PSM to get test coverage
        psm = new PSM(address(usdc), address(sDai), address(rateProvider));

        assertEq(address(psm.asset0()),       address(usdc));
        assertEq(address(psm.asset1()),       address(sDai));
        assertEq(address(psm.rateProvider()), address(rateProvider));

        assertEq(psm.asset0Precision(), 10 ** usdc.decimals());
        assertEq(psm.asset1Precision(), 10 ** sDai.decimals());
    }

}

// TODO: Add fuzz tests
// TODO: Add overflow boundary tests

contract PSMPreviewFunctionTests is PSMTestBase {

    function test_previewSwapAssetZeroToOne() public {
        assertEq(psm.previewSwapAssetZeroToOne(1), 0.8e12);
        assertEq(psm.previewSwapAssetZeroToOne(2), 1.6e12);
        assertEq(psm.previewSwapAssetZeroToOne(3), 2.4e12);

        assertEq(psm.previewSwapAssetZeroToOne(1e6), 0.8e18);
        assertEq(psm.previewSwapAssetZeroToOne(2e6), 1.6e18);
        assertEq(psm.previewSwapAssetZeroToOne(3e6), 2.4e18);

        assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 0.8000008e18);

        rateProvider.__setConversionRate(1.6e27);

        assertEq(psm.previewSwapAssetZeroToOne(1), 0.625e12);
        assertEq(psm.previewSwapAssetZeroToOne(2), 1.25e12);
        assertEq(psm.previewSwapAssetZeroToOne(3), 1.875e12);

        assertEq(psm.previewSwapAssetZeroToOne(1e6), 0.625e18);
        assertEq(psm.previewSwapAssetZeroToOne(2e6), 1.25e18);
        assertEq(psm.previewSwapAssetZeroToOne(3e6), 1.875e18);

        assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 0.625000625e18);

        rateProvider.__setConversionRate(0.8e27);

        assertEq(psm.previewSwapAssetZeroToOne(1), 1.25e12);
        assertEq(psm.previewSwapAssetZeroToOne(2), 2.5e12);
        assertEq(psm.previewSwapAssetZeroToOne(3), 3.75e12);

        assertEq(psm.previewSwapAssetZeroToOne(1e6), 1.25e18);
        assertEq(psm.previewSwapAssetZeroToOne(2e6), 2.5e18);
        assertEq(psm.previewSwapAssetZeroToOne(3e6), 3.75e18);

        assertEq(psm.previewSwapAssetZeroToOne(1.000001e6), 1.25000125e18);
    }

    function test_previewSwapAssetOneToZero() public {
        assertEq(psm.previewSwapAssetOneToZero(1), 0);
        assertEq(psm.previewSwapAssetOneToZero(2), 0);
        assertEq(psm.previewSwapAssetOneToZero(3), 0);
        assertEq(psm.previewSwapAssetOneToZero(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.previewSwapAssetOneToZero(1e12), 1);
        assertEq(psm.previewSwapAssetOneToZero(2e12), 2);
        assertEq(psm.previewSwapAssetOneToZero(3e12), 3);
        assertEq(psm.previewSwapAssetOneToZero(4e12), 5);

        assertEq(psm.previewSwapAssetOneToZero(1e18), 1.25e6);
        assertEq(psm.previewSwapAssetOneToZero(2e18), 2.5e6);
        assertEq(psm.previewSwapAssetOneToZero(3e18), 3.75e6);
        assertEq(psm.previewSwapAssetOneToZero(4e18), 5e6);

        assertEq(psm.previewSwapAssetOneToZero(1.000001e18), 1.250001e6);

        rateProvider.__setConversionRate(1.6e27);

        assertEq(psm.previewSwapAssetOneToZero(1), 0);
        assertEq(psm.previewSwapAssetOneToZero(2), 0);
        assertEq(psm.previewSwapAssetOneToZero(3), 0);
        assertEq(psm.previewSwapAssetOneToZero(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.previewSwapAssetOneToZero(1e12), 1);
        assertEq(psm.previewSwapAssetOneToZero(2e12), 3);
        assertEq(psm.previewSwapAssetOneToZero(3e12), 4);
        assertEq(psm.previewSwapAssetOneToZero(4e12), 6);

        assertEq(psm.previewSwapAssetOneToZero(1e18), 1.6e6);
        assertEq(psm.previewSwapAssetOneToZero(2e18), 3.2e6);
        assertEq(psm.previewSwapAssetOneToZero(3e18), 4.8e6);
        assertEq(psm.previewSwapAssetOneToZero(4e18), 6.4e6);

        rateProvider.__setConversionRate(0.8e27);

        assertEq(psm.previewSwapAssetOneToZero(1), 0);
        assertEq(psm.previewSwapAssetOneToZero(2), 0);
        assertEq(psm.previewSwapAssetOneToZero(3), 0);
        assertEq(psm.previewSwapAssetOneToZero(4), 0);

        // 1e-6 with 18 decimal precision
        assertEq(psm.previewSwapAssetOneToZero(1e12), 0);
        assertEq(psm.previewSwapAssetOneToZero(2e12), 1);
        assertEq(psm.previewSwapAssetOneToZero(3e12), 2);
        assertEq(psm.previewSwapAssetOneToZero(4e12), 3);

        assertEq(psm.previewSwapAssetOneToZero(1e18), 0.8e6);
        assertEq(psm.previewSwapAssetOneToZero(2e18), 1.6e6);
        assertEq(psm.previewSwapAssetOneToZero(3e18), 2.4e6);
        assertEq(psm.previewSwapAssetOneToZero(4e18), 3.2e6);
    }

}

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
