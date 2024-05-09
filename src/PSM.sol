// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { console2 } from "forge-std/console2.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}

// TODO: Add events and corresponding tests
// TODO: Determine what admin functionality we want (fees?)
// TODO: Add interface with natspec and inherit
// TODO: Discuss rounding up/down
// TODO: Frontrunning attack
contract PSM {

    using SafeERC20 for IERC20;

    // NOTE: Assumption is made that asset1 is the yield-bearing counterpart of asset0.
    //       Examples: asset0 = USDC and asset1 = sDAI, asset0 = WETH and asset1 = wstETH.
    IERC20 public immutable asset0;
    IERC20 public immutable asset1;

    address public immutable rateProvider;

    uint256 public immutable asset0Precision;
    uint256 public immutable asset1Precision;

    uint256 public totalShares;

    mapping(address user => uint256 shares) public shares;

    constructor(address asset0_, address asset1_, address rateProvider_) {
        require(asset0_       != address(0), "PSM/invalid-asset0");
        require(asset1_       != address(0), "PSM/invalid-asset1");
        require(rateProvider_ != address(0), "PSM/invalid-rateProvider");

        asset0       = IERC20(asset0_);
        asset1       = IERC20(asset1_);
        rateProvider = rateProvider_;

        asset0Precision = 10 ** IERC20(asset0_).decimals();
        asset1Precision = 10 ** IERC20(asset1_).decimals();
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

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

        // Convert asset to 1e18 precision denominated in value of asset0 then convert to shares.
        uint256 newShares = convertToShares(_getAssetValue(asset, assetsToDeposit));

        shares[msg.sender] += newShares;
        totalShares        += newShares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetsToDeposit);
    }

    function withdraw(address asset, uint256 maxAssetsToWithdraw) external {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");

        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        uint256 assetsToWithdraw = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        // Convert asset to 1e18 precision denominated in value of asset0 then convert to shares.
        uint256 sharesToBurn = convertToShares(_getAssetValue(asset, assetsToWithdraw));

        // If the asset amount is higher than the user's share balance, burn all shares and withdraw
        // the maximum amount of assets.
        if (sharesToBurn > shares[msg.sender]) {
            sharesToBurn     = shares[msg.sender];
            assetsToWithdraw = _getAssetsByValue(asset, convertToAssets(sharesToBurn));
        }

        // Above logic allows for unchecked to be used.
        unchecked {
            shares[msg.sender] -= sharesToBurn;
            totalShares        -= sharesToBurn;
        }

        IERC20(asset).safeTransfer(msg.sender, assetsToWithdraw);
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

    function convertToAssets(uint256 numShares) public view returns (uint256) {
        uint256 totalShares_ = totalShares;
        if (totalShares_ != 0) {
            return numShares * getPsmTotalValue() / totalShares_;
        }
        return numShares;
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

    function previewSwapAssetZeroToOne(uint256 amountIn) public view returns (uint256) {
        return amountIn
            * 1e27
            * asset1Precision
            / IRateProviderLike(rateProvider).getConversionRate()
            / asset0Precision;
    }

    function previewSwapAssetOneToZero(uint256 amountIn) public view returns (uint256) {
        return amountIn
            * IRateProviderLike(rateProvider).getConversionRate()
            * asset0Precision
            / 1e27
            / asset1Precision;
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
        // NOte: Multiplying by 1e18 and dividing by 1e9 cancels to 1e9 in denominator
        return amount * IRateProviderLike(rateProvider).getConversionRate() / 1e9 / asset1Precision;
    }

}
