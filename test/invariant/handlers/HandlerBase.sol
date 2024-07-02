// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { CommonBase }    from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdUtils }      from "forge-std/StdUtils.sol";

import { PSM3 } from "src/PSM3.sol";

contract HandlerBase is CommonBase, StdCheatsSafe, StdUtils {

    PSM3 public psm;

    MockERC20[3] public assets;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2
    ) {
        psm = psm_;

        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

}
