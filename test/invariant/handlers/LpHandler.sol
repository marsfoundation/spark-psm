// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase } from "test/invariant/handlers/HandlerBase.sol";

import { PSM3 } from "src/PSM3.sol";

contract LpHandler is HandlerBase {

    address[] public lps;

    uint256 public depositCount;
    uint256 public withdrawCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256   lpCount
    ) HandlerBase(psm_, asset0, asset1, asset2) {
        for (uint256 i = 0; i < lpCount; i++) {
            lps.push(makeAddr(string(abi.encodePacked("lp-", vm.toString(i)))));
        }
    }

    function _getLP(uint256 indexSeed) internal view returns (address) {
        return lps[indexSeed % lps.length];
    }

    function deposit(uint256 assetSeed, uint256 lpSeed, uint256 amount) public {
        MockERC20 asset = _getAsset(assetSeed);
        address   lp    = _getLP(lpSeed);

        amount = _bound(amount, 1, 1e12 * 10 ** asset.decimals());

        vm.startPrank(lp);
        asset.mint(lp, amount);
        asset.approve(address(psm), amount);
        psm.deposit(address(asset), lp, amount);
        vm.stopPrank();

        depositCount++;
    }

    function withdraw(uint256 assetSeed, uint256 lpSeed, uint256 amount) public {
        MockERC20 asset = _getAsset(assetSeed);
        address   lp    = _getLP(lpSeed);

        amount = _bound(amount, 1, 1e12 * 10 ** asset.decimals());

        vm.prank(lp);
        psm.withdraw(address(asset), lp, amount);
        vm.stopPrank();

        withdrawCount++;
    }

}
