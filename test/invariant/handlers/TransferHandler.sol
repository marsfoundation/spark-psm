// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract TransferHandler is HandlerBase {

    uint256 public transferCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2
    ) HandlerBase(psm_, asset0, asset1, asset2) {}

    function transfer(uint256 assetSeed, string memory senderSeed, uint256 amount) external {
        MockERC20 asset = _getAsset(assetSeed);
        address   sender = makeAddr(senderSeed);

        // Bounding to 1 million here because 1 trillion introduces unrealistic conditions with
        // large rounding errors. Would rather keep tolerances smaller with a lower upper bound
        // on transfer amounts.
        amount = _bound(amount, 1, 1_000_000 * 10 ** asset.decimals());

        asset.mint(sender, amount);

        vm.prank(sender);
        asset.transfer(address(psm), amount);

        transferCount += 1;
    }

}
