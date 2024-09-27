// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

import { StdCheats } from "forge-std/StdCheats.sol";

import { SSRAuthOracle } from "lib/xchain-ssr-oracle/src/SSRAuthOracle.sol";
import { ISSROracle }    from "lib/xchain-ssr-oracle/src/interfaces/ISSROracle.sol";

contract TimeBasedRateHandler is HandlerBase, StdCheats {

    uint256 public ssr;

    uint256 constant TWENTY_PCT_APY_SSR = 1.000000005781378656804591712e27;

    SSRAuthOracle public ssrOracle;

    uint256 public setSUSDSDataCount;
    uint256 public warpCount;

    constructor(PSM3 psm_, SSRAuthOracle ssrOracle_) HandlerBase(psm_) {
        ssrOracle = ssrOracle_;
    }

    // This acts as a receiver on an L2.
    function setSUSDSData(uint256 newSsr) external {
        // 1. Setup and bounds
        ssr = _bound(newSsr, 1e27, TWENTY_PCT_APY_SSR);

        // Update rho to be current, update chi based on current rate
        uint256 rho = block.timestamp;
        uint256 chi = ssrOracle.getConversionRate(rho);

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToAssetValue(1e18);
        uint256 startingValue      = psm.totalAssets();

        // 3. Perform action against protocol
        ssrOracle.setSUSDSData(ISSROracle.SUSDSData({
            ssr: uint96(ssr),
            chi: uint120(chi),
            rho: uint40(rho)
        }));

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18) + 1,
            startingConversion,
            "TimeBasedRateHandler/getSUSDSData/conversion-rate-decrease"
        );

        assertGe(
            psm.totalAssets() + 1,
            startingValue,
            "TimeBasedRateHandler/getSUSDSData/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        setSUSDSDataCount++;
    }

    function warp(uint256 skipTime) external {
        // 1. Setup and bounds
        uint256 warpTime = _bound(skipTime, 0, 10 days);

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToAssetValue(1e18);
        uint256 startingValue      = psm.totalAssets();

        // 3. Perform action against protocol
        skip(warpTime);

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18),
            startingConversion,
            "RateSetterHandler/warp/conversion-rate-decrease"
        );

        assertGe(
            psm.totalAssets(),
            startingValue,
            "RateSetterHandler/warp/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        warpCount++;
    }

}
