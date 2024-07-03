// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract TransferHandler is HandlerBase {

    MockERC20[3] public assets;

    uint256 public transferCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2
    ) HandlerBase(psm_) {
        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function transfer(uint256 assetSeed, string memory senderSeed, uint256 amount) external {
        // 1. Setup and bounds

        MockERC20 asset = _getAsset(assetSeed);
        address   sender = makeAddr(senderSeed);

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // Bounding to 10 million here because 1 trillion introduces unrealistic conditions with
        // large rounding errors. Would rather keep tolerances smaller with a lower upper bound
        // on transfer amounts.
        amount = _bound(amount, 1, 10_000_000 * 10 ** asset.decimals());

        // 3. Perform action against protocol
        asset.mint(sender, amount);
        vm.prank(sender);
        asset.transfer(address(psm), amount);

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18) + 1,
            startingConversion,
            "TransferHandler/transfer/conversion-rate-decrease"
        );

        assertGe(
            psm.getPsmTotalValue() + 1,
            startingValue,
            "TransferHandler/transfer/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        transferCount += 1;
    }

}
