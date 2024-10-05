// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

contract OwnerHandler is HandlerBase {

    MockERC20 public usdc;

    constructor(PSM3 psm_, MockERC20 usdc_) HandlerBase(psm_) {
        usdc = usdc_;
    }

    function setPocket(string memory salt) public {
        address newPocket = makeAddr(salt);

        // Avoid "same pocket" error
        if (newPocket == psm.pocket()) {
            newPocket = makeAddr(string(abi.encodePacked(salt, "salt")));
        }

        // Assumption is made that the pocket will always infinite approve the PSM
        vm.prank(newPocket);
        usdc.approve(address(psm), type(uint256).max);

        uint256 oldPocketBalance   = usdc.balanceOf(psm.pocket());
        uint256 newPocketBalance   = usdc.balanceOf(newPocket);
        uint256 totalAssets        = psm.totalAssets();
        uint256 startingConversion = psm.convertToAssetValue(1e18);

        address oldPocket = psm.pocket();

        psm.setPocket(newPocket);

        // Old pocket should be cleared of USDC
        assertEq(
            usdc.balanceOf(oldPocket),
            0,
            "OwnerHandler/old-pocket-balance"
        );

        // New pocket should get full pocket balance
        assertEq(
            usdc.balanceOf(newPocket),
            newPocketBalance + oldPocketBalance,
            "OwnerHandler/new-pocket-balance"
        );

        // Total assets should be exactly the same
        assertEq(
            psm.totalAssets(),
            totalAssets,
            "OwnerHandler/total-assets"
        );

        // Conversion rate should be exactly the same
        assertEq(
            psm.convertToAssetValue(1e18),
            startingConversion,
            "OwnerHandler/starting-conversion"
        );
    }

}
