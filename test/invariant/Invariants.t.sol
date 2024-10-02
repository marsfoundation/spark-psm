// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SSRAuthOracle } from "lib/xchain-ssr-oracle/src/SSRAuthOracle.sol";
import { ISSROracle }    from "lib/xchain-ssr-oracle/src/interfaces/ISSROracle.sol";

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
        _deposit(address(usds), BURN_ADDRESS, 1e18);
    }

    /**********************************************************************************************/
    /*** Invariant assertion functions                                                          ***/
    /**********************************************************************************************/

    function _checkInvariant_A() public view {
        uint256 lpShares = 1e18;  // Seed amount

        // NOTE: Can be refactored to be dynamic
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
        uint256 expectedUsdcInflows  = 0;
        uint256 expectedUsdsInflows  = 1e18;  // Seed amount
        uint256 expectedSUsdsInflows = 0;

        uint256 expectedUsdcOutflows  = 0;
        uint256 expectedUsdsOutflows  = 0;
        uint256 expectedSUsdsOutflows = 0;

        for(uint256 i; i < 3; i++) {
            address lp      = lpHandler.lps(i);
            address swapper = swapperHandler.swappers(i);

            expectedUsdcInflows  += lpHandler.lpDeposits(lp, address(usdc));
            expectedUsdsInflows  += lpHandler.lpDeposits(lp, address(usds));
            expectedSUsdsInflows += lpHandler.lpDeposits(lp, address(susds));

            expectedUsdcInflows  += swapperHandler.swapsIn(swapper, address(usdc));
            expectedUsdsInflows  += swapperHandler.swapsIn(swapper, address(usds));
            expectedSUsdsInflows += swapperHandler.swapsIn(swapper, address(susds));

            expectedUsdcOutflows  += lpHandler.lpWithdrawals(lp, address(usdc));
            expectedUsdsOutflows  += lpHandler.lpWithdrawals(lp, address(usds));
            expectedSUsdsOutflows += lpHandler.lpWithdrawals(lp, address(susds));

            expectedUsdcOutflows  += swapperHandler.swapsOut(swapper, address(usdc));
            expectedUsdsOutflows  += swapperHandler.swapsOut(swapper, address(usds));
            expectedSUsdsOutflows += swapperHandler.swapsOut(swapper, address(susds));
        }

        if (address(transferHandler) != address(0)) {
            expectedUsdcInflows  += transferHandler.transfersIn(address(usdc));
            expectedUsdsInflows  += transferHandler.transfersIn(address(usds));
            expectedSUsdsInflows += transferHandler.transfersIn(address(susds));
        }

        assertEq(usdc.balanceOf(address(psm)),  expectedUsdcInflows  - expectedUsdcOutflows);
        assertEq(usds.balanceOf(address(psm)),  expectedUsdsInflows  - expectedUsdsOutflows);
        assertEq(susds.balanceOf(address(psm)), expectedSUsdsInflows - expectedSUsdsOutflows);
    }

    function _checkInvariant_F() public view {
        uint256 totalValueSwappedIn;
        uint256 totalValueSwappedOut;

        for(uint256 i; i < 3; i++) {
            address swapper = swapperHandler.swappers(i);

            uint256 valueSwappedIn  = swapperHandler.valueSwappedIn(swapper);
            uint256 valueSwappedOut = swapperHandler.valueSwappedOut(swapper);

            // TODO: Paramaterize the TimeBasedHandler and make this function take parameters.
            //       At really high rates the rounding errors can be quite large.
            assertApproxEqAbs(
                valueSwappedIn,
                valueSwappedOut,
                swapperHandler.swapperSwapCount(swapper) * 3e12
            );
            assertGe(valueSwappedIn, valueSwappedOut);

            totalValueSwappedIn  += valueSwappedIn;
            totalValueSwappedOut += valueSwappedOut;
        }

        // Rounding error of up to 3e12 per swap, always rounding in favour of the PSM
        assertApproxEqAbs(
            totalValueSwappedIn,
            totalValueSwappedOut,
            swapperHandler.swapCount() * 3e12
        );
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
        uint256 usdsValue  = usds.balanceOf(lp);
        uint256 usdcValue  = usdc.balanceOf(lp) * 1e12;
        uint256 susdsValue = susds.balanceOf(lp) * rateProvider.getConversionRate() / 1e27;

        return usdsValue + usdcValue + susdsValue;
    }

    function _getLpDepositsValue(address lp) internal view returns (uint256) {
        uint256 depositValue =
            lpHandler.lpDeposits(lp, address(usds)) +
            lpHandler.lpDeposits(lp, address(usdc)) * 1e12 +
            lpHandler.lpDeposits(lp, address(susds)) * rateProvider.getConversionRate() / 1e27;

        uint256 withdrawValue =
            lpHandler.lpWithdrawals(lp, address(usds)) +
            lpHandler.lpWithdrawals(lp, address(usdc)) * 1e12 +
            lpHandler.lpWithdrawals(lp, address(susds)) * rateProvider.getConversionRate() / 1e27;

        return withdrawValue > depositValue ? 0 : depositValue - withdrawValue;
    }

    function _getLpAPR(address lp, uint256 initialValue, uint256 warpTime)
        internal view returns (uint256)
    {
        uint256 lpValue = psm.convertToAssetValue(psm.shares(lp));
        return (lpValue - initialValue) * 1e18 * 365 days / initialValue / warpTime;
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
        _withdraw(address(usds),  lp0, type(uint256).max);
        _withdraw(address(usdc),  lp0, type(uint256).max);
        _withdraw(address(susds), lp0, type(uint256).max);

        _withdraw(address(usds),  lp1, type(uint256).max);
        _withdraw(address(usdc),  lp1, type(uint256).max);
        _withdraw(address(susds), lp1, type(uint256).max);

        _withdraw(address(usds),  lp2, type(uint256).max);
        _withdraw(address(usdc),  lp2, type(uint256).max);
        _withdraw(address(susds), lp2, type(uint256).max);

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
        // 1e18 share seed deposit, rounding for each LP.
        assertApproxEqAbs(totalWithdrawals, psmTotalValue - seedValue, 3);

        // Get the starting sum of all LPs' deposits and withdrawals.
        uint256 sumStartingValue =
            (lp0DepositsValue  + lp1DepositsValue  + lp2DepositsValue) +
            (lp0WithdrawsValue + lp1WithdrawsValue + lp2WithdrawsValue);

        // Assert that the sum of all LPs' deposits and withdrawals equals
        // the sum of all LPs' resulting token holdings. Rounding errors are accumulated to the
        // burn address.
        assertApproxEqAbs(sumLpValue, sumStartingValue, seedValue - startingSeedValue + 3);

        // NOTE: Below logic is not realistic, shown to demonstrate precision.

        _withdraw(address(usds),  BURN_ADDRESS, type(uint256).max);
        _withdraw(address(usdc),  BURN_ADDRESS, type(uint256).max);
        _withdraw(address(susds), BURN_ADDRESS, type(uint256).max);

        // When all funds are completely withdrawn, the sum of all funds withdrawn is equal to the
        // sum of value of all LPs including the burn address. All rounding errors get reduced to
        // a few wei. Using 20 as a low tolerance that still allows for high rounding errors with
        // large rate changes in long campaigns.
        assertApproxEqAbs(
            sumLpValue + _getLpTokenValue(BURN_ADDRESS),
            sumStartingValue + startingSeedValue,
            20
        );

        // All funds can always be withdrawn completely (rounding in withdrawal against users).
        assertEq(psm.totalShares(), 0);
        assertLe(psm.totalAssets(), 20);
    }

    function _warpAndAssertConsistentValueAccrual() public {
        address lp0 = lpHandler.lps(0);
        address lp1 = lpHandler.lps(1);
        address lp2 = lpHandler.lps(2);

        // Ensure that all users have a minimum balance of shares to improve precision
        _deposit(address(usds), lp0, 100_000e18);
        _deposit(address(usds), lp1, 100_000e18);
        _deposit(address(usds), lp2, 100_000e18);

        uint256 lp0Value = psm.convertToAssetValue(psm.shares(lp0));
        uint256 lp1Value = psm.convertToAssetValue(psm.shares(lp1));
        uint256 lp2Value = psm.convertToAssetValue(psm.shares(lp2));

        skip(1 days);

        uint256 lp0Apr1 = _getLpAPR(lp0, lp0Value, 1 days);

        uint256 tolerance = 0.000_000_000_001e18;

        // Check that the other LPs have the same APR.
        assertApproxEqRel(_getLpAPR(lp1, lp1Value, 1 days), lp0Apr1, tolerance);
        assertApproxEqRel(_getLpAPR(lp2, lp2Value, 1 days), lp0Apr1, tolerance);

        skip(364 days);

        uint256 lp0Apr2 = _getLpAPR(lp0, lp0Value, 365 days);

        // Since value accrues compounding per second, the APR representation will increase
        assertGe(lp0Apr2, lp0Apr1);

        // Check that the APY remains the same after a year, comparing to LP0 to also ensure
        // consistency across LPs.
        assertApproxEqRel(_getLpAPR(lp1, lp1Value, 365 days), lp0Apr2, tolerance);
        assertApproxEqRel(_getLpAPR(lp2, lp2Value, 365 days), lp0Apr2, tolerance);
    }

}

contract PSMInvariants_ConstantRate_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler      = new LpHandler(psm, usdc, usds, susds, 3);
        swapperHandler = new SwapperHandler(psm, usdc, usds, susds, 3);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_ConstantRate_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler       = new LpHandler(psm, usdc, usds, susds, 3);
        swapperHandler  = new SwapperHandler(psm, usdc, usds, susds, 3);
        transferHandler = new TransferHandler(psm, usdc, usds, susds);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_RateSetting_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler         = new LpHandler(psm, usdc, usds, susds, 3);
        rateSetterHandler = new RateSetterHandler(psm, address(rateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(psm, usdc, usds, susds, 3);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_RateSetting_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        lpHandler         = new LpHandler(psm, usdc, usds, susds, 3);
        rateSetterHandler = new RateSetterHandler(psm, address(rateProvider), 1.25e27);
        swapperHandler    = new SwapperHandler(psm, usdc, usds, susds, 3);
        transferHandler   = new TransferHandler(psm, usdc, usds, susds);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        _withdrawAllPositions();
    }

}

contract PSMInvariants_TimeBasedRateSetting_NoTransfer is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        SSRAuthOracle ssrOracle = new SSRAuthOracle();

        // Workaround to initialize PSM with an oracle that does not return zero
        // This gets overwritten by the handler
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));
        ssrOracle.setSUSDSData(ISSROracle.SUSDSData({
            ssr: uint96(1e27),
            chi: uint120(1e27),
            rho: uint40(block.timestamp)
        }));
        ssrOracle.revokeRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));

        // Redeploy PSM with new rate provider
        psm = new PSM3(owner, address(usdc), address(usds), address(susds), address(ssrOracle));

        // Seed the new PSM with 1e18 shares (1e18 of value)
        _deposit(address(usds), BURN_ADDRESS, 1e18);

        lpHandler            = new LpHandler(psm, usdc, usds, susds, 3);
        swapperHandler       = new SwapperHandler(psm, usdc, usds, susds, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(psm, ssrOracle);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        rateProvider = IRateProviderLike(address(ssrOracle));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setSUSDSData(1e27);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        uint256 snapshot = vm.snapshot();

        _warpAndAssertConsistentValueAccrual();

        vm.revertTo(snapshot);

        _withdrawAllPositions();
    }

}

contract PSMInvariants_TimeBasedRateSetting_WithTransfers is PSMInvariantTestBase {

    function setUp() public override {
        super.setUp();

        SSRAuthOracle ssrOracle = new SSRAuthOracle();

        // Workaround to initialize PSM with an oracle that does not return zero
        // This gets overwritten by the handler
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));
        ssrOracle.setSUSDSData(ISSROracle.SUSDSData({
            ssr: uint96(1e27),
            chi: uint120(1e27),
            rho: uint40(block.timestamp)
        }));
        ssrOracle.revokeRole(ssrOracle.DATA_PROVIDER_ROLE(), address(this));

        // Redeploy PSM with new rate provider
        psm = new PSM3(owner, address(usdc), address(usds), address(susds), address(ssrOracle));

        // Seed the new PSM with 1e18 shares (1e18 of value)
        _deposit(address(usds), BURN_ADDRESS, 1e18);

        lpHandler            = new LpHandler(psm, usdc, usds, susds, 3);
        swapperHandler       = new SwapperHandler(psm, usdc, usds, susds, 3);
        timeBasedRateHandler = new TimeBasedRateHandler(psm, ssrOracle);
        transferHandler      = new TransferHandler(psm, usdc, usds, susds);

        // Handler acts in the same way as a receiver on L2, so add as a data provider to the
        // oracle.
        ssrOracle.grantRole(ssrOracle.DATA_PROVIDER_ROLE(), address(timeBasedRateHandler));

        rateProvider = IRateProviderLike(address(ssrOracle));

        // Manually set initial values for the oracle through the handler to start
        timeBasedRateHandler.setSUSDSData(1e27);

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

    function invariant_F() public view {
        _checkInvariant_F();
    }

    function afterInvariant() public {
        uint256 snapshot = vm.snapshot();

        _warpAndAssertConsistentValueAccrual();

        vm.revertTo(snapshot);

        _withdrawAllPositions();
    }

}
