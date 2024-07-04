// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { console, HandlerBase, PSM3 } from "test/invariant/handlers/HandlerBase.sol";

contract SwapperHandler is HandlerBase {

    MockERC20[3] public assets;

    address[] public swappers;

    mapping(address user => mapping(address asset => uint256 deposits)) public swapsIn;
    mapping(address user => mapping(address asset => uint256 deposits)) public swapsOut;

    // Used for assertions, assumption made that LpHandler is used with at least 1 LP.
    address public lp0;

    uint256 public swapCount;
    uint256 public zeroBalanceCount;

    constructor(
        PSM3      psm_,
        MockERC20 asset0,
        MockERC20 asset1,
        MockERC20 asset2,
        uint256   swapperCount
    ) HandlerBase(psm_) {
        assets[0] = asset0;
        assets[1] = asset1;
        assets[2] = asset2;

        for (uint256 i = 0; i < swapperCount; i++) {
            swappers.push(makeAddr(string(abi.encodePacked("swapper-", vm.toString(i)))));
        }

        // Derive LP-0 address for assertion
        lp0 = makeAddr("lp-0");
    }

    function _getAsset(uint256 indexSeed) internal view returns (MockERC20) {
        return assets[indexSeed % assets.length];
    }

    function _getSwapper(uint256 indexSeed) internal view returns (address) {
        return swappers[indexSeed % swappers.length];
    }

    function swapExactIn(
        uint256 assetInSeed,
        uint256 assetOutSeed,
        uint256 swapperSeed,
        uint256 amountIn,
        uint256 minAmountOut
    )
        public
    {
        // 1. Setup and bounds

        // Prevent overflow in if statement below
        assetOutSeed = _bound(assetOutSeed, 0, type(uint256).max - 2);

        MockERC20 assetIn  = _getAsset(assetInSeed);
        MockERC20 assetOut = _getAsset(assetOutSeed);
        address   swapper  = _getSwapper(swapperSeed);

        // Handle case where randomly selected assets match
        if (assetIn == assetOut) {
            assetOut = _getAsset(assetOutSeed + 2);
        }

        // By calculating the amount of assetIn we can get from the max asset out, we can
        // determine the max amount of assetIn we can swap since its the same both ways.
        uint256 maxAmountIn = psm.previewSwapExactIn(
            address(assetOut),
            address(assetIn),
            assetOut.balanceOf(address(psm))
        );

        // If there's zero balance a swap can't be performed
        if (maxAmountIn == 0) {
            zeroBalanceCount++;
            return;
        }

        amountIn = _bound(amountIn, 1, maxAmountIn);

        // Fuzz between zero and the expected amount out from the swap
        minAmountOut = _bound(
            minAmountOut,
            0,
            psm.previewSwapExactIn(address(assetIn), address(assetOut), amountIn)
        );

        // 2. Cache starting state
        uint256 startingConversion        = psm.convertToAssetValue(1e18);
        uint256 startingConversionMillion = psm.convertToAssetValue(1e6 * 1e18);
        uint256 startingConversionLp0     = psm.convertToAssetValue(psm.shares(lp0));
        uint256 startingValue             = psm.getPsmTotalValue();

        // 3. Perform action against protocol
        vm.startPrank(swapper);
        assetIn.mint(swapper, amountIn);
        assetIn.approve(address(psm), amountIn);
        uint256 amountOut = psm.swapExactIn(
            address(assetIn),
            address(assetOut),
            amountIn,
            minAmountOut,
            swapper,
            0
        );
        vm.stopPrank();

        // 4. Update ghost variable(s)
        swapsIn[swapper][address(assetIn)]   += amountIn;
        swapsOut[swapper][address(assetOut)] += amountOut;

        // 5. Perform action-specific assertions

        // Rounding because of USDC precision, a the conversion rate of a
        // user's position can fluctuate by up to 2e12 per 1e18 shares
        assertApproxEqAbs(
            psm.convertToAssetValue(1e18),
            startingConversion,
            2e12,
            "SwapperHandler/swap/conversion-rate-change"
        );

        // Demonstrate rounding scales with shares
        // TODO: Reinvestigate this assertion once swap fuzz tests are in place
        assertApproxEqAbs(
            psm.convertToAssetValue(1_000_000e18),
            startingConversionMillion,
            2_000_000e12, // 2e18 of value
            "SwapperHandler/swap/conversion-rate-change-million"
        );

        // Decrease in value from rounding is capped at 2e12
        assertGe(
            psm.convertToAssetValue(1_000_000e18) + 2e12,
            startingConversionMillion,
            "SwapperHandler/swap/conversion-rate-million-decrease"
        );

        // Disregard this assertion if the LP has less than a dollar of value
        if (startingConversionLp0 > 1e18) {
            // Position values can fluctuate by up to 0.00000002% on swaps
            assertApproxEqRel(
                psm.convertToAssetValue(psm.shares(lp0)),
                startingConversionLp0,
                0.000002e18,
                "SwapperHandler/swap/conversion-rate-change-lp"
            );
        }

        // Decrease in value from rounding is capped at 2e12
        assertGe(
            psm.convertToAssetValue(psm.shares(lp0)) + 2e12,
            startingConversionLp0,
            "SwapperHandler/swap/conversion-rate-lp-decrease"
        );

        // PSM value can fluctuate by up to 0.00000002% on swaps because of USDC rounding
        assertApproxEqRel(
            psm.getPsmTotalValue(),
            startingValue,
            0.000002e18,
            "SwapperHandler/swap/psm-total-value-change"
        );

        // Decrease in value from rounding is capped at 2e12
        assertGe(
            psm.getPsmTotalValue() + 2e12,
            startingValue,
            "SwapperHandler/swap/psm-total-value-decrease"
        );

        // 6. Update metrics tracking state
        swapCount++;
    }

    // TODO: Add swapExactOut in separate PR

}
