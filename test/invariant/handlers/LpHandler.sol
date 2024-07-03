// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

contract LpHandler is HandlerBase {

    MockERC20[3] public assets;

    address[] public lps;

    uint256 public depositCount;
    uint256 public withdrawCount;

    mapping(address user => mapping(address asset => uint256 deposits))    public lpDeposits;
    mapping(address user => mapping(address asset => uint256 withdrawals)) public lpWithdrawals;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256   lpCount
    ) HandlerBase(psm_) {
        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;

        for (uint256 i = 0; i < lpCount; i++) {
            lps.push(makeAddr(string(abi.encodePacked("lp-", vm.toString(i)))));
        }
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function _getLP(uint256 indexSeed) internal view returns (address) {
        return lps[indexSeed % lps.length];
    }

    function deposit(uint256 assetSeed, uint256 lpSeed, uint256 amount) public {
        // 1. Setup and bounds
        MockERC20 asset = _getAsset(assetSeed);
        address   lp    = _getLP(lpSeed);

        amount = _bound(amount, 1, 1e12 * 10 ** asset.decimals());

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // 3. Perform action against protocol
        vm.startPrank(lp);
        asset.mint(lp, amount);
        asset.approve(address(psm), amount);
        psm.deposit(address(asset), lp, amount);
        vm.stopPrank();

        // 4. Update ghost variable(s)
        lpDeposits[lp][address(asset)] += amount;

        // 5. Perform action-specific assertions
        assertApproxEqAbs(
            psm.convertToShares(1e18),
            startingConversion,
            2,
            "LpHandler/deposit/conversion-rate-change"
        );

        assertGe(
            psm.getPsmTotalValue() + 1,
            startingValue,
            "LpHandler/deposit/psm-total-value-decrease"
        );

        // 6. Update metrics tracking state
        depositCount++;
    }

    function withdraw(uint256 assetSeed, uint256 lpSeed, uint256 amount) public {
        // 1. Setup and bounds
        MockERC20 asset = _getAsset(assetSeed);
        address   lp    = _getLP(lpSeed);

        amount = _bound(amount, 1, 1e12 * 10 ** asset.decimals());

        // 2. Cache starting state
        uint256 startingConversion = psm.convertToShares(1e18);
        uint256 startingValue      = psm.getPsmTotalValue();

        // 3. Perform action against protocol
        vm.prank(lp);
        uint256 withdrawAmount = psm.withdraw(address(asset), lp, amount);
        vm.stopPrank();

        // 4. Update ghost variable(s)
        lpWithdrawals[lp][address(asset)] += withdrawAmount;

        // 5. Perform action-specific assertions

        // Larger tolerance for rounding errors because of burning more shares on USDC withdraw
        assertApproxEqAbs(
            psm.convertToShares(1e18),
            startingConversion,
            1e12,
            "LpHandler/withdraw/conversion-rate-change"
        );

        assertLe(
            psm.getPsmTotalValue(),
            startingValue + 1,
            "LpHandler/withdraw/psm-total-value-increase"
        );

        // 6. Update metrics tracking state
        withdrawCount++;
    }

}

/**
 * Add before/after value assertions for all
 * Add APY calc for after hook in timebased
 * Add ghost variable for swapper and transfer and sum those
 */
