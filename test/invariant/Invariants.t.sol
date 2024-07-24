// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { DSRAuthOracle } from "lib/xchain-dsr-oracle/src/DSRAuthOracle.sol";

import { PSM3 } from "src/PSM3.sol";

import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

import { PSMTestBase } from "test/PSMTestBase.sol";

import { LpHandler }            from "test/invariant/handlers/LpHandler.sol";
import { RateSetterHandler }    from "test/invariant/handlers/RateSetterHandler.sol";
import { SwapperHandler }       from "test/invariant/handlers/SwapperHandler.sol";
import { TimeBasedRateHandler } from "test/invariant/handlers/TimeBasedRateHandler.sol";
import { TransferHandler }      from "test/invariant/handlers/TransferHandler.sol";

abstract contract PSMInvariantTestBase is PSMTestBase {

    LpHandler            public lpHandler;
    RateSetterHandler    public rateSetterHandler;
    SwapperHandler       public swapperHandler;
    TransferHandler      public transferHandler;
    TimeBasedRateHandler public timeBasedRateHandler;

    address BURN_ADDRESS = address(0);

    // NOTE [CRITICAL]: All invariant tests are operating under the assumption that the initial seed
    //                  deposit of 1e18 shares has been made. This is a key requirement and
    //                  assumption for all invariant tests.
    function setUp() public virtual override {
        super.setUp();

        // Seed the pool with 1e18 shares (1e18 of value)
        _deposit(address(dai), BURN_ADDRESS, 1e18);
    }

    /**********************************************************************************************/
    /*** Invariant assertion functions                                                          ***/
    /**********************************************************************************************/

    function _checkInvariant_A() public view {
        uint256 lpShares = 1e18;  // Seed amount

        // TODO: Update to be dynamic
        for (uint256 i = 0; i < 3; i++) {
            lpShares += psm.shares(lpHandler.lps(i));
        }

        assertEq(lpShares, psm.totalShares());
    }

    function _checkInvariant_B() public view {
        assertApproxEqAbs(
            psm.totalAssets(),
            psm.convertToAssetValue(psm.totalShares()),
            4
        );
    }

    function _checkInvariant_C() public view {
        uint256 lpAssetValue = psm.convertToAssetValue(1e18);  // Seed amount

        for (uint256 i = 0; i < 3; i++) {
            lpAssetValue += psm.convertToAssetValue(psm.shares(lpHandler.lps(i)));
        }

        assertApproxEqAbs(lpAssetValue, psm.totalAssets(), 4);
    }

    // This might be failing because of swap rounding errors.
    function _checkInvariant_D() public view {
        // Seed amounts
        uint256 lpDeposits   = 1e18;
        uint256 lpAssetValue = psm.convertToAssetValue(1e18);

        for (uint256 i = 0; i < 3; i++) {
            address lp = lpHandler.lps(i);

            lpDeposits   += _getLpDepositsValue(lp);
            lpAssetValue += psm.convertToAssetValue(psm.shares(lp));
        }

        // LPs position value can increase from transfers into the PSM and from swapping rounding
        // errors increasing the value of the PSM slightly.
        // Allow a 2e12 tolerance for negative rounding on conversion calculations.
        assertGe(lpAssetValue + 2e12, lpDeposits);

        // Include seed deposit, allow for 2e12 negative tolerance.
        assertGe(psm.totalAssets() + 2e12, lpDeposits);
    }

    function _checkInvariant_E() public view {
        uint256 expectedUsdcBalance = 0;
        uint256 expectedDaiBalance  = 1e18;  // Seed amount
        uint256 expectedSDaiBalance = 0;

        for(uint256 i; i < 3; i++) {
            address lp      = lpHandler.lps(i);
            address swapper = swapperHandler.swappers(i);

            expectedUsdcBalance += lpHandler.lpDeposits(lp, address(usdc));
            expectedDaiBalance  += lpHandler.lpDeposits(lp, address(dai));
            expectedSDaiBalance += lpHandler.lpDeposits(lp, address(sDai));

            expectedUsdcBalance += swapperHandler.swapsIn(swapper, address(usdc));
            expectedDaiBalance  += swapperHandler.swapsIn(swapper, address(dai));
            expectedSDaiBalance += swapperHandler.swapsIn(swapper, address(sDai));
        }

        if (address(transferHandler) != address(0)) {
            expectedUsdcBalance += transferHandler.transfersIn(address(usdc));
            expectedDaiBalance  += transferHandler.transfersIn(address(dai));
            expectedSDaiBalance += transferHandler.transfersIn(address(sDai));
        }

        // Loop twice to avoid underflows between LPs
        for(uint256 i; i < 3; i++) {
            address lp      = lpHandler.lps(i);
            address swapper = swapperHandler.swappers(i);

            expectedUsdcBalance -= lpHandler.lpWithdrawals(lp, address(usdc));
            expectedDaiBalance  -= lpHandler.lpWithdrawals(lp, address(dai));
            expectedSDaiBalance -= lpHandler.lpWithdrawals(lp, address(sDai));

            expectedUsdcBalance -= swapperHandler.swapsOut(swapper, address(usdc));
            expectedDaiBalance  -= swapperHandler.swapsOut(swapper, address(dai));
            expectedSDaiBalance -= swapperHandler.swapsOut(swapper, address(sDai));
        }

        assertEq(usdc.balanceOf(address(psm)), expectedUsdcBalance);
        assertEq(dai.balanceOf(address(psm)),  expectedDaiBalance);
        assertEq(sDai.balanceOf(address(psm)), expectedSDaiBalance);
    }

    function _checkInvariant_F() public view {
        uint256 totalValueSwappedIn;
        uint256 totalValueSwappedOut;

        for(uint256 i; i < 3; i++) {
            address swapper = swapperHandler.swappers(i);

            totalValueSwappedIn +=
                swapperHandler.swapsIn(swapper, address(usdc)) * 1e12 +
                swapperHandler.swapsIn(swapper, address(dai)) +
                swapperHandler.swapsIn(swapper, address(sDai)) * rateProvider.getConversionRate() / 1e27;
        }

        // Loop twice to avoid underflows between LPs
        for(uint256 i; i < 3; i++) {
            address swapper = swapperHandler.swappers(i);

            totalValueSwappedOut +=
                swapperHandler.swapsOut(swapper, address(usdc)) * 1e12 +
                swapperHandler.swapsOut(swapper, address(dai)) +
                swapperHandler.swapsOut(swapper, address(sDai)) * rateProvider.getConversionRate() / 1e27;
        }

        // Rounding error of up to 1e12 per swap, always rounding in favour of the PSM
        assertApproxEqAbs(totalValueSwappedIn, totalValueSwappedOut, swapperHandler.swapCount() * 1e12);
        assertGe(totalValueSwappedIn, totalValueSwappedOut);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _logHandlerCallCounts() public view {
        console.log("depositCount    ", lpHandler.depositCount());
        console.log("withdrawCount   ", lpHandler.withdrawCount());
        console.log("swapCount       ", swapperHandler.swapCount());
        console.log("zeroBalanceCount", swapperHandler.zeroBalanceCount());
        console.log("setRateCount    ", rateSetterHandler.setRateCount());
        console.log(
            "sum             ",
            lpHandler.depositCount() +
            lpHandler.withdrawCount() +
            swapperHandler.swapCount() +
            swapperHandler.zeroBalanceCount() +
            rateSetterHandler.setRateCount()
        );
    }

    function _getLpTokenValue(address lp) internal view returns (uint256) {
        uint256 daiValue  = dai.balanceOf(lp);
        uint256 usdcValue = usdc.balanceOf(lp) * 1e12;
        uint256 sDaiValue = sDai.balanceOf(lp) * rateProvider.getConversionRate() / 1e27;

        return daiValue + usdcValue + sDaiValue;
    }

    function _getLpDepositsValue(address lp) internal view returns (uint256) {
        uint256 depositValue =
            lpHandler.lpDeposits(lp, address(dai)) +
            lpHandler.lpDeposits(lp, address(usdc)) * 1e12 +
            lpHandler.lpDeposits(lp, address(sDai)) * rateProvider.getConversionRate() / 1e27;

        uint256 withdrawValue =
            lpHandler.lpWithdrawals(lp, address(dai)) +
            lpHandler.lpWithdrawals(lp, address(usdc)) * 1e12 +
            lpHandler.lpWithdrawals(lp, address(sDai)) * rateProvider.getConversionRate() / 1e27;

        return withdrawValue > depositValue ? 0 : depositValue - withdrawValue;
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

        uint256 psmTotalValue = psm.totalAssets();

        uint256 startingSeedValue = psm.convertToAssetValue(1e18);

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

        uint256 seedValue = psm.convertToAssetValue(1e18);

        // PSM is empty (besides seed amount).
        assertEq(psm.totalShares(), 1e18);
        assertEq(psm.totalAssets(), seedValue);

        // Tokens held by LPs are equal to the sum of their previous balance
        // plus the amount of value originally represented in the PSM's shares.
        // There can be rounding here because of share burning up to 2e12 when withdrawing USDC.
        // It should be noted that LP2 here has a rounding error of 4e12 since both LP0 and LP1
        // could have rounding errors that accumulate to LP2.
        assertApproxEqAbs(_getLpTokenValue(lp0), lp0DepositsValue + lp0WithdrawsValue, 2e12);
        assertApproxEqAbs(_getLpTokenValue(lp1), lp1DepositsValue + lp1WithdrawsValue, 2e12);
        assertApproxEqAbs(_getLpTokenValue(lp2), lp2DepositsValue + lp2WithdrawsValue, 4e12);

        // All rounding errors from LPs can accrue to the burn address after withdrawals are made.
        assertApproxEqAbs(seedValue, startingSeedValue, 6e12);

        // Current value of all LPs' token holdings.
        uint256 sumLpValue = _getLpTokenValue(lp0) + _getLpTokenValue(lp1) + _getLpTokenValue(lp2);

        // Total amount just withdrawn from the PSM.
        uint256 totalWithdrawals
            = sumLpValue - (lp0WithdrawsValue + lp1WithdrawsValue + lp2WithdrawsValue);

        // Assert that all funds were withdrawn equals the original value of the PSM minus the
        // 1e18 share seed deposit.
        assertApproxEqAbs(totalWithdrawals, psmTotalValue - seedValue, 3);

        // Get the starting sum of all LPs' deposits and withdrawals.
        uint256 sumStartingValue =
            (lp0DepositsValue  + lp1DepositsValue  + lp2DepositsValue) +
            (lp0WithdrawsValue + lp1WithdrawsValue + lp2WithdrawsValue);

        // Assert that the sum of all LPs' deposits and withdrawals equals
        // the sum of all LPs' resulting token holdings. Rounding errors are accumulated to the
        // burn address.
        assertApproxEqAbs(sumLpValue, sumStartingValue, seedValue - startingSeedValue + 2);

        // NOTE: Below logic is not realistic, shown to demonstrate precision.

        _withdraw(address(dai),  BURN_ADDRESS, type(uint256).max);
        _withdraw(address(usdc), BURN_ADDRESS, type(uint256).max);
        _withdraw(address(sDai), BURN_ADDRESS, type(uint256).max);

        // When all funds are completely withdrawn, the sum of all funds withdrawn is equal to the
        // sum of value of all LPs including the burn address. All rounding errors get reduced to
        // a few wei.
        assertApproxEqAbs(
            sumLpValue + _getLpTokenValue(BURN_ADDRESS),
            sumStartingValue + startingSeedValue,
            5
        );

        // All funds can always be withdrawn completely.
        assertEq(psm.totalShares(), 0);
        assertEq(psm.totalAssets(), 0);
    }

}

contract PSMInvariants_ConstantRate_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler      = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler = new SwapperHandler(psm, dai, usdc, sDai, 3);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    function invariant_D() public view {
        _checkInvariant_D();
    }

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_ConstantRate_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler       = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler  = new SwapperHandler(psm, dai, usdc, sDai, 3);
        transferHandler = new TransferHandler(psm, dai, usdc, sDai);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(transferHandler));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_RateSetting_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler         = new LpHandler(psm, dai, usdc, sDai, 3);
        rateSetterHandler = new RateSetterHandler(psm, address(rateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(psm, dai, usdc, sDai, 3);

        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(swapperHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_RateSetting_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler         = new LpHandler(psm, dai, usdc, sDai, 3);
        rateSetterHandler = new RateSetterHandler(psm, address(rateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(psm, dai, usdc, sDai, 3);
        transferHandler   = new TransferHandler(psm, dai, usdc, sDai);

        targetContract(address(lpHandler));
        targetContract(address(rateSetterHandler));
        targetContract(address(swapperHandler));
        targetContract(address(transferHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_TimeBasedRateSetting_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        DSRAuthOracle dsrOracle = new DSRAuthOracle();

        // Redeploy PSM with new rate provider
        psm = new PSM3(address(dai), address(usdc), address(sDai), address(dsrOracle));

        // Seed the new PSM with 1e18 shares (1e18 of value)
        _deposit(address(dai), BURN_ADDRESS, 1e18);

        lpHandler            = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler       = new SwapperHandler(psm, dai, usdc, sDai, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(psm, dsrOracle);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        dsrOracle.grantRole(dsrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        rateProvider = IRateProviderLike(address(dsrOracle));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setPotData(1e27);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(timeBasedRateHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_TimeBasedRateSetting_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        DSRAuthOracle dsrOracle = new DSRAuthOracle();

        // Redeploy PSM with new rate provider
        psm = new PSM3(address(dai), address(usdc), address(sDai), address(dsrOracle));

        // Seed the new PSM with 1e18 shares (1e18 of value)
        _deposit(address(dai), BURN_ADDRESS, 1e18);

        lpHandler            = new LpHandler(psm, dai, usdc, sDai, 3);
        swapperHandler       = new SwapperHandler(psm, dai, usdc, sDai, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(psm, dsrOracle);
        transferHandler      = new TransferHandler(psm, dai, usdc, sDai);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        dsrOracle.grantRole(dsrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        rateProvider = IRateProviderLike(address(dsrOracle));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setPotData(1e27);

        targetContract(address(lpHandler));
        targetContract(address(swapperHandler));
        targetContract(address(timeBasedRateHandler));
        targetContract(address(transferHandler));

        // Check that LPs used for swap assertions are correct to not get zero values
        assertEq(swapperHandler.lp0(), lpHandler.lps(0));
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

    // No invariant D because rate changes lead to large rounding errors when compared with
    // ghost variables

    function invariant_E() public view {
        _checkInvariant_E();
    }

    function skip_invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}
