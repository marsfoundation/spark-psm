// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils }  from "forge-std/StdUtils.sol";

import { DSRAuthOracle } from "lib/xchain-dsr-oracle/src/DSRAuthOracle.sol";
import { IDSROracle }    from "lib/xchain-dsr-oracle/src/interfaces/IDSROracle.sol";

contract TimeBasedRateHandler is StdCheats, StdUtils {

    uint256 public dsr;
    uint256 public chi;
    uint256 public rho;

    uint256 constant ONE_HUNDRED_PCT_APY_DSR = 1.000000021979553151239153027e27;

    DSRAuthOracle public dsrOracle;

    uint256 public setRateCount;

    constructor(DSRAuthOracle dsrOracle_) {
        dsrOracle = dsrOracle_;
    }

    // This acts as a receiver on an L2.
    function setPotData(uint256 newDsr, uint256 newRho) external {
        dsr = _bound(newDsr, 1e27, ONE_HUNDRED_PCT_APY_DSR);
        rho = _bound(newRho, rho,  block.timestamp);

        // If chi hasn't been set yet, set to 1e27, else recalculate it in the same way it would
        // happen during a refresh.
        uint256 rate = dsrOracle.getConversionRate();
        uint256 chi  = rate == 0 ? 1e27 : rate;

        dsrOracle.setPotData(IDSROracle.PotData({
            dsr: uint96(dsr),
            chi: uint120(chi),
            rho: uint40(rho)
        }));
    }

    function warp(uint256 skipTime) external {
        skip(_bound(skipTime, 0, 45 days));
    }

}
