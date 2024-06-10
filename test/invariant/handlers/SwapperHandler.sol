// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract SwapperHandler is HandlerBase {

    address[] public swappers;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256 lpCount
    ) HandlerBase(psm_, asset0, asset1, asset2) {
        for (uint256 i = 0; i < lpCount; i++) {
            swappers.push(makeAddr(string(abi.encodePacked("swapper-", i))));
        }
    }

    function _getSwapper(uint256 indexSeed) internal view returns (address) {
        return swappers[_bound(indexSeed, 0, swappers.length - 1)];
    }

    function swap(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amount
    )
        public
    {
        MockERC20 assetIn  = _getAsset(assetInSeed);
        MockERC20 assetOut = _getAsset(assetOutSeed);
        address   swapper  = _getSwapper(swapperSeed);

        amount = _bound(amount, 1, 1);  // TODO: Change this to calculate max amount out

        vm.startPrank(swapper);
        assetIn.mint(swapper, amount);
        assetIn.approve(address(psm), amount);
        psm.swap(address(assetIn), address(assetOut), amount, 0, swapper, 0);  // TODO: Update amountOut
        vm.stopPrank();

        count++;
    }

}
