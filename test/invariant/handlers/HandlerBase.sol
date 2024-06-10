// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { CommonBase }    from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdUtils }      from "forge-std/StdUtils.sol";

import { PSM3 } from "src/PSM3.sol";

contract LPHandler is CommonBase, StdCheatsSafe, StdUtils {

    MockERC20[3] public assets;

    address[] public lps;

    PSM3 public psm;

    uint256 public count;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256 lpCount
    ) {
        psm = psm_;

        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;

        for (uint256 i = 0; i < lpCount; i++) {
            lps.push(makeAddr(string(abi.encodePacked("LP", i))));
        }
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[_bound(indexSeed, 0, 2)];
    }

    function _getLP(uint256 indexSeed) internal view returns (address) {
        return lps[_bound(indexSeed, 0, lps.length - 1)];
    }

    function deposit(uint256 indexSeed, address user, uint256 amount) public {
        MockERC20 asset = _getAsset(indexSeed);
        address   lp    = _getLP(indexSeed);

        console.log("asset", address(asset));

        amount = _bound(amount, 1, 1e18);  // TODO: Change this to something dynamic

        vm.startPrank(user);
        asset.mint(user, amount);
        asset.approve(address(psm), amount);
        psm.deposit(address(asset), lp, amount);
        vm.stopPrank();

        count++;
    }
}
