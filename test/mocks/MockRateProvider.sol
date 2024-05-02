// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

contract MockRateProvider {

    uint256 public conversionRate;

    function __setConversionRate(uint256 conversionRate_) external {
        conversionRate = conversionRate_;
    }

    function getConversionRate() external view returns (uint256) {
        return conversionRate;
    }

}
