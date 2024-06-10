// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract LPHandler is HandlerBase {

    address[] public lps;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256 lpCount
    ) HandlerBase(psm_, asset0, asset1, asset2) {
        for (uint256 i = 0; i < lpCount; i++) {
            lps.push(makeAddr(string(abi.encodePacked("LP", i))));
        }
    }

    function _getLP(uint256 indexSeed) internal view returns (address) {
        return lps[_bound(indexSeed, 0, lps.length - 1)];
    }

    function deposit(uint256 indexSeed, address user, uint256 amount) public {
        MockERC20 asset = _getAsset(indexSeed);
        address   lp    = _getLP(indexSeed);

        amount = _bound(amount, 1, 1e18);  // TODO: Change this to something dynamic

        vm.startPrank(user);
        asset.mint(user, amount);
        asset.approve(address(psm), amount);
        psm.deposit(address(asset), lp, amount);
        vm.stopPrank();

        count++;
    }

}
