// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { PSM3 } from "src/PSM3.sol";

contract PSM3Harness is PSM3 {

    constructor(
        address owner_,
        address asset0_,
        address asset1_,
        address asset2_,
        address rateProvider_
    )
        PSM3(owner_, asset0_, asset1_, asset2_, rateProvider_) {}

    function getAssetValue(address asset, uint256 amount, bool roundUp)
        external view returns (uint256)
    {
        return _getAssetValue(asset, amount, roundUp);
    }

    function getAsset0Value(uint256 amount) external view returns (uint256) {
        return _getAsset0Value(amount);
    }

    function getAsset1Value(uint256 amount) external view returns (uint256) {
        return _getAsset1Value(amount);
    }

    function getAsset2Value(uint256 amount, bool roundUp) external view returns (uint256) {
        return _getAsset2Value(amount, roundUp);
    }

}
