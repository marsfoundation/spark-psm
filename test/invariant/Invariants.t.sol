// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { LpHandler }      from "test/invariant/handlers/LpHandler.sol";
import { SwapperHandler } from "test/invariant/handlers/SwapperHandler.sol";

contract PSMInvariantTestBase is PSMTestBase {

    LpHandler      public lpHandler;
    SwapperHandler public swapperHandler;

    /**********************************************************************************************/
    /*** Invariant assertion functions                                                          ***/
    /**********************************************************************************************/

    function _checkInvariant_A() public view {
        assertEq(
            psm.shares(address(lpHandler.lps(0))) +
            psm.shares(address(lpHandler.lps(1))) +
            psm.shares(address(lpHandler.lps(2))),
            psm.totalShares()
        );
    }

    function _checkInvariant_B() public view {
        assertApproxEqAbs(
            psm.getPsmTotalValue(),
            psm.convertToAssetValue(psm.totalShares()),
            2
        );
    }

    function _checkInvariant_C() public view {
        assertApproxEqAbs(
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(0)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(1)))) +
            psm.convertToAssetValue(psm.shares(address(lpHandler.lps(2)))),
            psm.getPsmTotalValue(),
            3
        );
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _logHandlerCallCounts() public view {
        console.log("depositCount    ", lpHandler.depositCount());
        console.log("withdrawCount   ", lpHandler.withdrawCount());
        console.log("swapCount       ", swapperHandler.swapCount());
        console.log("zeroBalanceCount", swapperHandler.zeroBalanceCount());
        console.log(
            "sum             ",
            lpHandler.depositCount() +
            lpHandler.withdrawCount() +
            swapperHandler.swapCount() +
            swapperHandler.zeroBalanceCount()
        );
    }

    function _getLpTokenValue(address lp) internal view returns (uint256) {
        uint256 daiValue  = dai.balanceOf(lp);
        uint256 usdcValue = usdc.balanceOf(lp) * 1e12;
        uint256 sDaiValue = sDai.balanceOf(lp) * rateProvider.getConversionRate() / 1e27;

        return daiValue + usdcValue + sDaiValue;
    }

    /**********************************************************************************************/
    /*** After invariant hook functions                                                         ***/
    /**********************************************************************************************/

    function _withdrawAllPositions() public {
        address lp0 = lpHandler.lps(0);
        address lp1 = lpHandler.lps(1);
        address lp2 = lpHandler.lps(2);

        // Get value of each LPs current deposits.
        uint256 lp0DepositsValue = psm.convertToAssetValue(psm.shares(lp0));
        uint256 lp1DepositsValue = psm.convertToAssetValue(psm.shares(lp1));
        uint256 lp2DepositsValue = psm.convertToAssetValue(psm.shares(lp2));

        // Get value of each LPs token holdings from previous withdrawals.
        uint256 lp0WithdrawsValue = _getLpTokenValue(lp0);
        uint256 lp1WithdrawsValue = _getLpTokenValue(lp1);
        uint256 lp2WithdrawsValue = _getLpTokenValue(lp2);

        uint256 psmTotalValue = psm.getPsmTotalValue();

        // Liquidity is unknown so withdraw all assets for all users to empty PSM.
        _withdraw(address(dai),  lp0, type(uint256).max);
        _withdraw(address(usdc), lp0, type(uint256).max);
        _withdraw(address(sDai), lp0, type(uint256).max);

        _withdraw(address(dai),  lp1, type(uint256).max);
        _withdraw(address(usdc), lp1, type(uint256).max);
        _withdraw(address(sDai), lp1, type(uint256).max);

        _withdraw(address(dai),  lp2, type(uint256).max);
        _withdraw(address(usdc), lp2, type(uint256).max);
        _withdraw(address(sDai), lp2, type(uint256).max);

        // All funds are completely withdrawn.
        assertEq(psm.shares(lp0), 0);
        assertEq(psm.shares(lp1), 0);
        assertEq(psm.shares(lp2), 0);

        // PSM is empty.
        assertEq(psm.totalShares(),      0);
        assertEq(psm.getPsmTotalValue(), 0);

        // Tokens held by LPs are equal to the sum of their previous balance
        // plus the amount of value originally represented in the PSM's shares.
        // There can be rounding here because of share burning up to 1e12 when withdrawing USDC.
        // It should be noted that LP2 here has a rounding error of 2e12 since both LP0 and LP1
        // could have rounding errors that accumulate to LP2.
        assertApproxEqAbs(_getLpTokenValue(lp0), lp0DepositsValue + lp0WithdrawsValue, 1e12);
        assertApproxEqAbs(_getLpTokenValue(lp1), lp1DepositsValue + lp1WithdrawsValue, 1e12);
        assertApproxEqAbs(_getLpTokenValue(lp2), lp2DepositsValue + lp2WithdrawsValue, 2e12);

        // Current value of all LPs' token holdings.
        uint256 sumLpValue = _getLpTokenValue(lp0) + _getLpTokenValue(lp1) + _getLpTokenValue(lp2);

        // Total amount just withdrawn from the PSM.
        uint256 totalWithdrawals
            = sumLpValue - (lp0WithdrawsValue + lp1WithdrawsValue + lp2WithdrawsValue);

        // Assert that all funds were withdrawn equals the original value of the PSM.
        assertApproxEqAbs(totalWithdrawals, psmTotalValue, 2);

        // Get the starting sum of all LPs' deposits and withdrawals.
        uint256 sumStartingValue =
            (lp0DepositsValue  + lp1DepositsValue  + lp2DepositsValue) +
            (lp0WithdrawsValue + lp1WithdrawsValue + lp2WithdrawsValue);

        // Assert that the sum of all LPs' deposits and withdrawals equals
        // the sum of all LPs' resulting token holdings. Rounding errors are accumulated by LPs.
        assertApproxEqAbs(sumLpValue, sumStartingValue, 6);
    }

}

contract PSMInvariants1 is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler      = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler = new SwapperHandler(psm, dai, usdc, sDai, 3);

        // TODO: Add rate updates
        rateProvider.__setConversionRate(1.25e27);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
    }

    function invariant_A() public view {
        _checkInvariant_A();
    }

    function invariant_B() public view {
        _checkInvariant_B();
    }

    function invariant_C() public view {
        _checkInvariant_C();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}
