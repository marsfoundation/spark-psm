// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract SwapperHandler is HandlerBase {

    address[] public swappers;

    uint256 public swapCount;
    uint256 public zeroBalanceCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256   lpCount
    ) HandlerBase(psm_, asset0, asset1, asset2) {
        for (uint256 i = 0; i < lpCount; i++) {
            swappers.push(makeAddr(string(abi.encodePacked("swapper-", vm.toString(i)))));
        }
    }

    function _getSwapper(uint256 indexSeed) internal view returns (address) {
        return swappers[indexSeed % swappers.length];
    }

    function swapExactIn(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amountIn,
        uint256 minAmountOut
    )
        public
    {
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
        uint256 maxAmountIn = psm.previewSwapExactIn(
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
            psm.previewSwapExactIn(address(assetIn), address(assetOut), amountIn)
        );

        vm.startPrank(swapper);
        assetIn.mint(swapper, amountIn);
        assetIn.approve(address(psm), amountIn);
        psm.swapExactIn(address(assetIn), address(assetOut), amountIn, minAmountOut, swapper, 0);
        vm.stopPrank();

        swapCount++;
    }

    // TODO: Add swapExactOut in separate PR

}
