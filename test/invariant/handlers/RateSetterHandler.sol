// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { StdUtils } from "forge-std/StdUtils.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract RateSetterHandler is StdUtils {

    uint256 public rate;

    MockRateProvider public rateProvider;

    uint256 public setRateCount;

    constructor(MockRateProvider rateProvider_, uint256 initialRate) {
        rateProvider = rateProvider_;
        rate         = initialRate;
    }

    function setRate(uint256 rateIncrease) external {
        // Increase the rate by up to 100%
        rate += _bound(rateIncrease, 0, 1e27);

        rateProvider.__setConversionRate(rate);

        setRateCount++;
    }

}
