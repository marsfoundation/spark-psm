// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console } from "forge-std/console.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils }  from "forge-std/StdUtils.sol";

import { DSRAuthOracle } from "lib/xchain-dsr-oracle/src/DSRAuthOracle.sol";
import { IDSROracle }    from "lib/xchain-dsr-oracle/src/interfaces/IDSROracle.sol";

contract TimeBasedRateHandler is StdCheats, StdUtils {

    uint256 public dsr;
    uint256 public chi;
    uint256 public rho;

    uint256 constant ONE_HUNDRED_PCT_APY_DSR = 1.00000002197955315123915302e27;

    DSRAuthOracle public dsrOracle;

    uint256 public setRateCount;

    constructor(DSRAuthOracle dsrOracle_) {
        dsrOracle = dsrOracle_;
    }

    // This acts as a receiver on an L2.
    // Note that the chi value is not derived from previous values, this is to test if
    // PSM will work as expected with different chi values.
    function setPotData(uint256 newDsr, uint256 newChi, uint256 newRho) external {
        dsr = _bound(newDsr, 1e27, ONE_HUNDRED_PCT_APY_DSR);
        chi = _bound(newChi, chi,  1e27);
        rho = _bound(newRho, rho,  block.timestamp);

        dsrOracle.setPotData(IDSROracle.PotData({
            dsr: uint96(dsr),
            chi: uint120(chi),
            rho: uint40(rho)
        }));
    }

    // function warp(uint256 skipTime) external {
    //     skip(_bound(skipTime, 0, 45 days));
    // }
}
