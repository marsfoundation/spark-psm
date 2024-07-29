// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { CommonBase }    from "forge-std/Base.sol";
import { console }       from "forge-std/console.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { stdMath }       from "forge-std/StdMath.sol";
import { StdUtils }      from "forge-std/StdUtils.sol";

import { PSM3 } from "src/PSM3.sol";

contract HandlerBase is CommonBase, StdCheatsSafe, StdUtils {

    PSM3 public psm;

    constructor(PSM3 psm_) {
        psm = psm_;
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    /**********************************************************************************************/
    /*** Assertion helpers (copied from ds-test and modified to revert)                         ***/
    /**********************************************************************************************/

    function assertEq(uint256 a, uint256 b, string memory err) internal view {
        if (a != b) {
            console.log("Error: a == b not satisfied [uint256]");
            console.log("      Left", a);
            console.log("     Right", b);
            revert(err);
        }
    }

    function assertGe(uint256 a, uint256 b, string memory err) internal view {
        if (a < b) {
            console.log("Error: a >= b not satisfied [uint256]");
            console.log("      Left", a);
            console.log("     Right", b);
            revert(err);
        }
    }

    function assertLe(uint256 a, uint256 b, string memory err) internal view {
        if (a > b) {
            console.log("Error: a <= b not satisfied [uint256]");
            console.log("      Left", a);
            console.log("     Right", b);
            revert(err);
        }
    }

    function assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta, string memory err)
        internal view
    {
        uint256 delta = stdMath.delta(a, b);

        if (delta > maxDelta) {
            console.log("Error: a ~= b not satisfied [uint]");
            console.log("      Left", a);
            console.log("     Right", b);
            console.log(" Max Delta", maxDelta);
            console.log("     Delta", delta);
            revert(err);
        }
    }

    function assertApproxEqRel(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta, // An 18 decimal fixed point number, where 1e18 == 100%
        string memory err
    ) internal virtual {
        // If the left is 0, right must be too.
        if (b == 0) return assertEq(a, b, string(abi.encodePacked("assertEq - ", err)));

        uint256 percentDelta = stdMath.percentDelta(a, b);

        if (percentDelta > maxPercentDelta) {
            console.log("Error: a ~= b not satisfied [uint]");
            console.log("              Left", a);
            console.log("             Right", b);
            console.log(" Max % Delta [wad]", maxPercentDelta);
            console.log("     % Delta [wad]", percentDelta);
            revert(err);
        }
    }

}
