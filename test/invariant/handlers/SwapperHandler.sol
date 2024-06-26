// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

contract SwapperHandler is HandlerBase {

    MockERC20[3] public assets;

    address[] public swappers;

    uint256 public swapCount;
    uint256 public zeroBalanceCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256   lpCount
    ) HandlerBase(psm_) {
        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;

        for (uint256 i = 0; i < lpCount; i++) {
            swappers.push(makeAddr(string(abi.encodePacked("swapper-", vm.toString(i)))));
        }
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function _getSwapper(uint256 indexSeed) internal view returns (address) {
        return swappers[indexSeed % swappers.length];
    }

    function swap(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amountIn,
        uint256 minAmountOut
    )
        public
    {
        // 1. Setup and bounds

        // Prevent overflow in if statement below
        assetOutSeed = _bound(assetOutSeed, 0, type(uint256).max - 2);

        MockERC20 assetIn  = _getAsset(assetInSeed);
        MockERC20 assetOut = _getAsset(assetOutSeed);
        address   swapper  = _getSwapper(swapperSeed);

        // Handle case where randomly selected assets match
        if (assetIn == assetOut) {
            assetOut = _getAsset(assetOutSeed + 2);
        }

        // By calculating the amount of assetIn we can get from the max asset out, we can
        // determine the max amount of assetIn we can swap since its the same both ways.
        uint256 maxAmountIn = psm.previewSwap(
            address(assetOut),
            address(assetIn),
            assetOut.balanceOf(address(psm))
        );

        // If there's zero balance a swap can't be performed
        if (maxAmountIn == 0) {
            zeroBalanceCount++;
            return;
        }

        amountIn = _bound(amountIn, 1, maxAmountIn);

        // Fuzz between zero and the expected amount out from the swap
        minAmountOut = _bound(
            minAmountOut,
            0,
            psm.previewSwap(address(assetIn), address(assetOut), amountIn)
        );

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // 3. Perform action against protocol

        vm.startPrank(swapper);
        assetIn.mint(swapper, amountIn);
        assetIn.approve(address(psm), amountIn);
        psm.swap(address(assetIn), address(assetOut), amountIn, minAmountOut, swapper, 0);
        vm.stopPrank();

        // 4. Perform action-specific assertions

        // Rounding because of USDC precision
        assertApproxEqAbs(
            psm.convertToShares(1e18),
            startingConversion,
            2e12,
            "SwapperHandler/swap/conversion-rate-change"
        );

        // Rounding because of USDC precision
        assertGe(
            psm.getPsmTotalValue() + 2e12,
            startingValue,
            "SwapperHandler/swap/psm-total-value-change"
        );

        // 5. Update metrics tracking state
        swapCount++;
    }

}
