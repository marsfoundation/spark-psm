// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}

// TODO: Add events and corresponding tests
// TODO: Determine what admin functionality we want (fees?)
// TODO: Add interface with natspec and inherit
// TODO: Discuss rounding up/down
contract PSM {

    using SafeERC20 for IERC20;

    // NOTE: Assumption is made that asset0 is the stablecoin and asset1 is the yield bearing asset
    IERC20 public immutable asset0;
    IERC20 public immutable asset1;

    IRateProviderLike public immutable rateProvider;

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
        rateProvider = IRateProviderLike(rateProvider_);

        asset0Precision = 10 ** IERC20(asset0_).decimals();
        asset1Precision = 10 ** IERC20(asset1_).decimals();
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    function swapAssetZeroToOne(uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn != 0, "PSM/invalid-amountIn");

        uint256 amountOut = previewSwapAssetZeroToOne(amountIn);

        require(amountOut >= minAmountOut, "PSM/invalid-amountOut");

        asset0.safeTransferFrom(msg.sender, address(this), amountIn);
        asset1.safeTransfer(msg.sender, amountOut);
    }

    function swapAssetOneToZero(uint256 amountIn, uint256 minAmountOut) external {
        require(amountIn != 0, "PSM/invalid-amountIn");

        uint256 amountOut = previewSwapAssetOneToZero(amountIn);

        require(amountOut >= minAmountOut, "PSM/invalid-amountOut");

        asset1.safeTransferFrom(msg.sender, address(this), amountIn);
        asset0.safeTransfer(msg.sender, amountOut);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    function deposit(address asset, uint256 assetsToDeposit) external {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");

        uint256 newShares = convertToShares(_getAssetValue(asset, assetsToDeposit));

        shares[msg.sender] += newShares;
        totalShares        += newShares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetsToDeposit);
    }

    function withdraw(address asset, uint256 sharesToWithdraw) external {
        require(asset == address(asset0) || asset == address(asset1), "PSM/invalid-asset");

        require(shares[msg.sender] >= sharesToWithdraw, "PSM/insufficient-shares");

        shares[msg.sender] -= sharesToWithdraw;
        totalShares        -= sharesToWithdraw;

        uint256 assetValue = convertToAssets(sharesToWithdraw);

        IERC20(asset).safeTransfer(msg.sender, _getAssetsByValue(asset, assetValue));
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    function convertToShares(uint256 assetValue) public view returns (uint256) {
        return assetValue * totalShares / getPsmTotalValue();
    }

    function convertToAssets(uint256 numShares) public view returns (uint256) {
        return numShares * getPsmTotalValue() / totalShares;
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
            / rateProvider.getConversionRate()
            / asset0Precision;
    }

    function previewSwapAssetOneToZero(uint256 amountIn) public view returns (uint256) {
        return amountIn
            * rateProvider.getConversionRate()
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

        // NOTE: Doing operation here to prevent overflow
        return assetValue * 1e27 / rateProvider.getConversionRate() * asset1Precision / 1e18;
    }

    function _getAsset0Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / asset0Precision;
    }

    function _getAsset1Value(uint256 amount) internal view returns (uint256) {
        return amount * rateProvider.getConversionRate() / 1e27;
    }

}
