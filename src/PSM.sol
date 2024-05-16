// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}

// TODO: Add events and corresponding tests
// TODO: Determine what admin functionality we want (fees?)
// TODO: Refactor into inheritance structure
// TODO: Add interface with natspec and inherit
// TODO: Prove that we're always rounding against user
// TODO: Frontrunning attack, donation attack, virtual balances?
// TODO: Figure out how to optimize require checks for assets in view functions
// TODO: Discuss if we should add ERC20 functionality
contract PSM {

    using SafeERC20 for IERC20;

    // NOTE: Assumption is made that asset2 is the yield-bearing counterpart of asset0 and asset1.
    //       Examples: asset0 = USDC, asset1 = DAI, asset2 = sDAI
    IERC20 public immutable asset0;
    IERC20 public immutable asset1;
    IERC20 public immutable asset2;

    address public immutable rateProvider;

    uint256 public immutable asset0Precision;
    uint256 public immutable asset1Precision;
    uint256 public immutable asset2Precision;

    uint256 public totalShares;

    mapping(address user => uint256 shares) public shares;

    constructor(address asset0_, address asset1_, address asset2_, address rateProvider_) {
        require(asset0_       != address(0), "PSM/invalid-asset0");
        require(asset1_       != address(0), "PSM/invalid-asset1");
        require(asset2_       != address(0), "PSM/invalid-asset1");
        require(rateProvider_ != address(0), "PSM/invalid-rateProvider");

        asset0 = IERC20(asset0_);
        asset1 = IERC20(asset1_);
        asset2 = IERC20(asset2_);

        rateProvider = rateProvider_;

        asset0Precision = 10 ** IERC20(asset0_).decimals();
        asset1Precision = 10 ** IERC20(asset1_).decimals();
        asset2Precision = 10 ** IERC20(asset1_).decimals();
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    function swap(address assetIn, address assetOut, uint256 amountIn, uint256 minAmountOut, address receiver) external {
        uint256 amountOut = _getAmountOut(assetIn, assetOut, amountIn);

        require(amountOut >= minAmountOut, "PSM/amountOut-too-low");

        IERC20(assetIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(assetOut).safeTransfer(receiver, amountOut);
    }

    function _getAmountOut(address assetIn, address assetOut, uint256 amountIn) internal view returns (uint256) {
        if (assetIn == address(asset0)) {
            if      (assetOut == address(asset1)) return previewStableSwap(amountIn, asset0Precision, asset1Precision);
            else if (assetOut == address(asset2)) return previewSwapToAsset2(asset0Precision, amountIn);
        }

        else if (assetIn == address(asset1)) {
            if      (assetOut == address(asset0)) return previewStableSwap(amountIn, asset1Precision, asset0Precision);
            else if (assetOut == address(asset2)) return previewSwapToAsset2(asset1Precision, amountIn);
        }

        else if (assetIn == address(asset2)) {
            if      (assetOut == address(asset0)) return previewSwapFromAsset2(asset0Precision, amountIn);
            else if (assetOut == address(asset1)) return previewSwapFromAsset2(asset1Precision, amountIn);
        }

        revert("PSM/invalid-asset");
    }

    function swapAssetZeroToOne(uint256 amountIn, uint256 minAmountOut, address receiver) external {
        require(amountIn != 0,          "PSM/invalid-amountIn");
        require(receiver != address(0), "PSM/invalid-receiver");

        uint256 amountOut = previewSwapAssetZeroToOne(amountIn);

        require(amountOut >= minAmountOut, "PSM/amountOut-too-low");

        asset0.safeTransferFrom(msg.sender, address(this), amountIn);
        asset1.safeTransfer(receiver, amountOut);
    }

    function swapAssetOneToZero(uint256 amountIn, uint256 minAmountOut, address receiver) external {
        require(amountIn != 0,          "PSM/invalid-amountIn");
        require(receiver != address(0), "PSM/invalid-receiver");

        uint256 amountOut = previewSwapAssetOneToZero(amountIn);

        require(amountOut >= minAmountOut, "PSM/amountOut-too-low");

        asset1.safeTransferFrom(msg.sender, address(this), amountIn);
        asset0.safeTransfer(receiver, amountOut);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    function deposit(address asset, uint256 assetsToDeposit) external {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");

        // Convert amount to 1e18 precision denominated in value of asset0 then convert to shares.
        uint256 newShares = convertToShares(_getAssetValue(asset, assetsToDeposit));

        shares[msg.sender] += newShares;
        totalShares        += newShares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetsToDeposit);
    }

    function withdraw(address asset, uint256 maxAssetsToWithdraw)
        external returns (uint256 assetsWithdrawn)
    {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");

        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        assetsWithdrawn = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        uint256 sharesToBurn = convertToShares(asset, assetsWithdrawn);

        if (sharesToBurn > shares[msg.sender]) {
            assetsWithdrawn = convertToAssets(asset, shares[msg.sender]);
            sharesToBurn    = convertToShares(asset, assetsWithdrawn);
        }

        unchecked {
            shares[msg.sender] -= sharesToBurn;
            totalShares        -= sharesToBurn;
        }

        IERC20(asset).safeTransfer(msg.sender, assetsWithdrawn);
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    function convertToShares(uint256 assetValue) public view returns (uint256) {
        uint256 totalValue = getPsmTotalValue();
        if (totalValue != 0) {
            return assetValue * totalShares / totalValue;
        }
        return assetValue;
    }

    function convertToShares(address asset, uint256 assets) public view returns (uint256) {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");
        return convertToShares(_getAssetValue(asset, assets));
    }

    function convertToAssetValue(uint256 numShares) public view returns (uint256) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ != 0) {
            return numShares * getPsmTotalValue() / totalShares_;
        }
        return numShares;
    }

    function convertToAssets(address asset, uint256 numShares) public view returns (uint256) {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");
        return _getAssetsByValue(asset, convertToAssetValue(numShares));
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    function getPsmTotalValue() public view returns (uint256) {
        return _getAsset0Value(asset0.balanceOf(address(this)))
            + _getAsset1Value(asset1.balanceOf(address(this)));
    }

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    function previewSwapToAsset2(uint256 assetPrecision, uint256 amountIn)
        public view returns (uint256)
    {
        return amountIn
            * 1e27
            * asset2Precision
            / IRateProviderLike(rateProvider).getConversionRate()
            / assetPrecision;
    }

    function previewSwapFromAsset2(uint256 assetPrecision, uint256 amountIn)
        public view returns (uint256)
    {
        return amountIn
            * IRateProviderLike(rateProvider).getConversionRate()
            * assetPrecision
            / 1e27
            / asset2Precision;
    }

    function previewStableSwap(
        uint256 amountIn,
        uint256 assetInPrecision,
        uint256 assetOutPrecision
    )
        public view returns (uint256)
    {
        return amountIn
            * assetInPrecision
            / assetOutPrecision;
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        if (asset == address(asset0)) {
            return _getAsset0Value(amount);
        }

        return _getAsset1Value(amount);
    }

    function _getAssetsByValue(address asset, uint256 assetValue) internal view returns (uint256) {
        if (asset == address(asset0)) {
            return assetValue * asset0Precision / 1e18;
        }

        // NOTE: Multiplying by 1e27 and dividing by 1e18 cancels to 1e9 in numerator
        return assetValue
            * 1e9
            * asset1Precision
            / IRateProviderLike(rateProvider).getConversionRate();
    }

    function _getAsset0Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / asset0Precision;
    }

    function _getAsset1Value(uint256 amount) internal view returns (uint256) {
        // NOTE: Multiplying by 1e18 and dividing by 1e9 cancels to 1e9 in denominator
        return amount * IRateProviderLike(rateProvider).getConversionRate() / 1e9 / asset1Precision;
    }

}
