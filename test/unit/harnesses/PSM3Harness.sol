// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { PSM3 } from "src/PSM3.sol";

contract PSM3Harness is PSM3 {

    constructor(
        address owner_,
        address usdc_,
        address usds_,
        address susds_,
        address rateProvider_
    )
        PSM3(owner_, usdc_, usds_, susds_, rateProvider_) {}

    function getAssetValue(address asset, uint256 amount, bool roundUp)
        external view returns (uint256)
    {
        return _getAssetValue(asset, amount, roundUp);
    }

    function getUsdcValue(uint256 amount) external view returns (uint256) {
        return _getUsdcValue(amount);
    }

    function getUsdsValue(uint256 amount) external view returns (uint256) {
        return _getUsdsValue(amount);
    }

    function getSUsdsValue(uint256 amount, bool roundUp) external view returns (uint256) {
        return _getSUsdsValue(amount, roundUp);
    }

}
