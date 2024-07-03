// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

import { StdCheats } from "forge-std/StdCheats.sol";

import { DSRAuthOracle } from "lib/xchain-dsr-oracle/src/DSRAuthOracle.sol";
import { IDSROracle }    from "lib/xchain-dsr-oracle/src/interfaces/IDSROracle.sol";

contract TimeBasedRateHandler is HandlerBase, StdCheats {

    uint256 public dsr;
    uint256 public rho;

    uint256 constant ONE_HUNDRED_PCT_APY_DSR = 1.00000002197955315123915302e27;

    DSRAuthOracle public dsrOracle;

    uint256 public setPotDataCount;
    uint256 public warpCount;

    constructor(PSM3 psm_, DSRAuthOracle dsrOracle_) HandlerBase(psm_) {
        dsrOracle = dsrOracle_;
    }

    // This acts as a receiver on an L2.
    // Note that the chi value is not derived from previous values, this is to test if
    // PSM will work as expected with different chi values.
    function setPotData(uint256 newDsr, uint256 newRho) external {
        // 1. Setup and bounds
        dsr = _bound(newDsr, 1e27, ONE_HUNDRED_PCT_APY_DSR);
        rho = _bound(newRho, rho,  block.timestamp);

        // If chi hasn't been set yet, set to 1e27
        uint256 rate = dsrOracle.getConversionRate();
        uint256 chi  = rate == 0 ? 1e27 : rate;

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

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
            psm.getPsmTotalValue() + 1,
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
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // 3. Perform action against protocol
        skip(warpTime);

        // 4. Perform action-specific assertions
        assertGe(
            psm.convertToAssetValue(1e18),
            startingConversion,
            "RateSetterHandler/warp/conversion-rate-decrease"
        );

        assertGe(
            psm.getPsmTotalValue(),
            startingValue,
            "RateSetterHandler/warp/psm-total-value-decrease"
        );

        // 5. Update metrics tracking state
        warpCount++;
    }

}
