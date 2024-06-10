// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IPSM } from "src/interfaces/IPSM.sol";

interface IRateProviderLike {
    function getConversionRate() external view returns (uint256);
}

// TODO: Determine what admin functionality we want (fees?)
// TODO: Refactor into inheritance structure
// TODO: Prove that we're always rounding against user
// TODO: Add receiver to deposit/withdraw
contract PSM is IPSM {

    using SafeERC20 for IERC20;

    uint256 internal immutable _asset0Precision;
    uint256 internal immutable _asset1Precision;
    uint256 internal immutable _asset2Precision;

    // NOTE: Assumption is made that asset2 is the yield-bearing counterpart of asset0 and asset1.
    //       Examples: asset0 = USDC, asset1 = DAI, asset2 = sDAI
    IERC20 public immutable asset0;
    IERC20 public immutable asset1;
    IERC20 public immutable asset2;

    address public immutable rateProvider;

    uint256 public totalShares;

    mapping(address user => uint256 shares) public shares;

    constructor(address asset0_, address asset1_, address asset2_, address rateProvider_) {
        require(asset0_       != address(0), "PSM/invalid-asset0");
        require(asset1_       != address(0), "PSM/invalid-asset1");
        require(asset2_       != address(0), "PSM/invalid-asset2");
        require(rateProvider_ != address(0), "PSM/invalid-rateProvider");

        require(asset0_ != asset1_, "PSM/asset0-asset1-same");
        require(asset0_ != asset2_, "PSM/asset0-asset2-same");
        require(asset1_ != asset2_, "PSM/asset1-asset2-same");

        asset0 = IERC20(asset0_);
        asset1 = IERC20(asset1_);
        asset2 = IERC20(asset2_);

        rateProvider = rateProvider_;

        _asset0Precision = 10 ** IERC20(asset0_).decimals();
        _asset1Precision = 10 ** IERC20(asset1_).decimals();
        _asset2Precision = 10 ** IERC20(asset2_).decimals();
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    function swap(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    )
        external override
    {
        require(amountIn != 0,          "PSM/invalid-amountIn");
        require(receiver != address(0), "PSM/invalid-receiver");

        uint256 amountOut = previewSwap(assetIn, assetOut, amountIn);

        require(amountOut >= minAmountOut, "PSM/amountOut-too-low");

        IERC20(assetIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(assetOut).safeTransfer(receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    function deposit(address asset, uint256 assetsToDeposit)
        external override returns (uint256 newShares)
    {
        newShares = previewDeposit(asset, assetsToDeposit);

        shares[msg.sender] += newShares;
        totalShares        += newShares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetsToDeposit);

        emit Deposit(asset, msg.sender, assetsToDeposit, newShares);
    }

    function withdraw(address asset, uint256 maxAssetsToWithdraw)
        external override returns (uint256 assetsWithdrawn)
    {
        uint256 sharesToBurn;

        ( sharesToBurn, assetsWithdrawn ) = previewWithdraw(asset, maxAssetsToWithdraw);

        unchecked {
            shares[msg.sender] -= sharesToBurn;
            totalShares        -= sharesToBurn;
        }

        IERC20(asset).safeTransfer(msg.sender, assetsWithdrawn);

        emit Withdraw(asset, msg.sender, assetsWithdrawn, sharesToBurn);
    }

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    function previewDeposit(address asset, uint256 assetsToDeposit)
        public view override returns (uint256)
    {
        require(_isValidAsset(asset), "PSM/invalid-asset");

        // Convert amount to 1e18 precision denominated in value of asset0 then convert to shares.
        return convertToShares(_getAssetValue(asset, assetsToDeposit));
    }

    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
    {
        require(_isValidAsset(asset), "PSM/invalid-asset");

        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        assetsWithdrawn = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        sharesToBurn = _convertToSharesRoundUp(_getAssetValue(asset, assetsWithdrawn));

        uint256 userShares = shares[msg.sender];

        if (sharesToBurn > userShares) {
            assetsWithdrawn = convertToAssets(asset, userShares);
            sharesToBurn    = userShares;
        }
    }

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    function previewSwap(address assetIn, address assetOut, uint256 amountIn)
        public view override returns (uint256 amountOut)
    {
        if (assetIn == address(asset0)) {
            if      (assetOut == address(asset1)) return _previewOneToOneSwap(amountIn, _asset0Precision, _asset1Precision);
            else if (assetOut == address(asset2)) return _previewSwapToAsset2(amountIn, _asset0Precision);
        }

        else if (assetIn == address(asset1)) {
            if      (assetOut == address(asset0)) return _previewOneToOneSwap(amountIn, _asset1Precision, _asset0Precision);
            else if (assetOut == address(asset2)) return _previewSwapToAsset2(amountIn, _asset1Precision);
        }

        else if (assetIn == address(asset2)) {
            if      (assetOut == address(asset0)) return _previewSwapFromAsset2(amountIn, _asset0Precision);
            else if (assetOut == address(asset1)) return _previewSwapFromAsset2(amountIn, _asset1Precision);
        }

        revert("PSM/invalid-asset");
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    function convertToAssets(address asset, uint256 numShares)
        public view override returns (uint256)
    {
        require(_isValidAsset(asset), "PSM/invalid-asset");

        uint256 assetValue = convertToAssetValue(numShares);

        if      (asset == address(asset0)) return assetValue * _asset0Precision / 1e18;
        else if (asset == address(asset1)) return assetValue * _asset1Precision / 1e18;

        // NOTE: Multiplying by 1e27 and dividing by 1e18 cancels to 1e9 in numerator
        return assetValue
            * 1e9
            * _asset2Precision
            / IRateProviderLike(rateProvider).getConversionRate();
    }

    function convertToAssetValue(uint256 numShares) public view override returns (uint256) {
        uint256 totalShares_ = totalShares;

        if (totalShares_ != 0) {
            return numShares * getPsmTotalValue() / totalShares_;
        }
        return numShares;
    }

    function convertToShares(uint256 assetValue) public view override returns (uint256) {
        uint256 totalValue = getPsmTotalValue();
        if (totalValue != 0) {
            return assetValue * totalShares / totalValue;
        }
        return assetValue;
    }

    function convertToShares(address asset, uint256 assets) public view override returns (uint256) {
        require(_isValidAsset(asset), "PSM/invalid-asset");
        return convertToShares(_getAssetValue(asset, assets));
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    function getPsmTotalValue() public view override returns (uint256) {
        return _getAsset0Value(asset0.balanceOf(address(this)))
            +  _getAsset1Value(asset1.balanceOf(address(this)))
            +  _getAsset2Value(asset2.balanceOf(address(this)));
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function _convertToSharesRoundUp(uint256 assetValue) internal view returns (uint256) {
        uint256 totalValue = getPsmTotalValue();
        if (totalValue != 0) {
            return _divUp(assetValue * totalShares, totalValue);
        }
        return assetValue;
    }

    function _divUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        if      (asset == address(asset0)) return _getAsset0Value(amount);
        else if (asset == address(asset1)) return _getAsset1Value(amount);
        else if (asset == address(asset2)) return _getAsset2Value(amount);
        else revert("PSM/invalid-asset");
    }

    function _getAsset0Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / _asset0Precision;
    }

    function _getAsset1Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / _asset1Precision;
    }

    function _getAsset2Value(uint256 amount) internal view returns (uint256) {
        // NOTE: Multiplying by 1e18 and dividing by 1e27 cancels to 1e9 in denominator
        return amount
            * IRateProviderLike(rateProvider).getConversionRate()
            / 1e9
            / _asset2Precision;
    }

    function _isValidAsset(address asset) internal view returns (bool) {
        return asset == address(asset0) || asset == address(asset1) || asset == address(asset2);
    }

    function _previewSwapToAsset2(uint256 amountIn, uint256 assetInPrecision)
        internal view returns (uint256)
    {
        return amountIn
            * 1e27
            / IRateProviderLike(rateProvider).getConversionRate()
            * _asset2Precision
            / assetInPrecision;
    }

    function _previewSwapFromAsset2(uint256 amountIn, uint256 assetInPrecision)
        internal view returns (uint256)
    {
        return amountIn
            * IRateProviderLike(rateProvider).getConversionRate()
            / 1e27
            * assetInPrecision
            / _asset2Precision;
    }

    function _previewOneToOneSwap(
        uint256 amountIn,
        uint256 assetInPrecision,
        uint256 assetOutPrecision
    )
        internal pure returns (uint256)
    {
        return amountIn
            * assetOutPrecision
            / assetInPrecision;
    }

}
