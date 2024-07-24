// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

import { StdCheats } from "forge-std/StdCheats.sol";

import { DSRAuthOracle } from "lib/xchain-dsr-oracle/src/DSRAuthOracle.sol";
import { IDSROracle }    from "lib/xchain-dsr-oracle/src/interfaces/IDSROracle.sol";

contract TimeBasedRateHandler is HandlerBase, StdCheats {

    uint256 public dsr;

    uint256 constant ONE_HUNDRED_PCT_APY_DSR = 1.000000021979553151239153027e27;

    DSRAuthOracle public dsrOracle;

    uint256 public setPotDataCount;
    uint256 public warpCount;

    constructor(PSM3 psm_, DSRAuthOracle dsrOracle_) HandlerBase(psm_) {
        dsrOracle = dsrOracle_;
    }

    // This acts as a receiver on an L2.
    // TODO: Discuss if rho should be set to a value between last rho and block.timestamp.
    //       This was the original approach but was causing the conversion rate to decrease.
    function setPotData(uint256 newDsr) external {
        // 1. Setup and bounds
        dsr = _bound(newDsr, 1e27, ONE_HUNDRED_PCT_APY_DSR);

        uint256 rho = block.timestamp;

        // If chi hasn't been set yet, set to 1e27, else recalculate it in the same way it would
        // happen during a refresh at `rho`
        uint256 rate = dsrOracle.getConversionRate(rho);
        uint256 chi  = rate == 0 ? 1e27 : rate;

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToAssetValue(1e18);
        uint256 startingValue      = psm.totalAssets();

        // 3. Perform action against protocol
        dsrOracle.setPotData(IDSROracle.PotData({
            dsr: uint96(dsr),
            chi: uint120(chi),
            rho: uint40(rho)
        }));

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18) + 1,
            startingConversion,
            "TimeBasedRateHandler/setPotData/conversion-rate-decrease"
        );

        assertGe(
            psm.totalAssets() + 1,
            startingValue,
            "TimeBasedRateHandler/setPotData/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        setPotDataCount++;
    }

    function warp(uint256 skipTime) external {
        // 1. Setup and bounds
        uint256 warpTime = _bound(skipTime, 0, 45 days);

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
