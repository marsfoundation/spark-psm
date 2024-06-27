// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

import { MockRateProvider } from "test/mocks/MockRateProvider.sol";

contract RateSetterHandler is HandlerBase {

    uint256 public rate;

    MockRateProvider public rateProvider;

    uint256 public setRateCount;

    constructor(PSM3 psm_, address rateProvider_, uint256 initialRate) HandlerBase(psm_) {
        rateProvider = MockRateProvider(rateProvider_);
        rate         = initialRate;
    }

    function setRate(uint256 rateIncrease) external {
        // 1. Setup and bounds

        // Increase the rate by up to 20%
        rate += bound(rateIncrease, 0, 0.2e27);

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // 3. Perform action against protocol
        rateProvider.__setConversionRate(rate);

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18) + 1,
            startingConversion,
            "RateSetterHandler/setRate/conversion-rate-decrease"
        );

        assertGe(
            psm.getPsmTotalValue() + 1,
            startingValue,
            "RateSetterHandler/setRate/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        setRateCount++;
    }
}
