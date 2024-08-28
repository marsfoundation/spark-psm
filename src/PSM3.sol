// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IPSM3 }             from "src/interfaces/IPSM3.sol";
import { IRateProviderLike } from "src/interfaces/IRateProviderLike.sol";

contract PSM3 is IPSM3 {

    using SafeERC20 for IERC20;

    uint256 internal immutable _asset0Precision;
    uint256 internal immutable _asset1Precision;
    uint256 internal immutable _asset2Precision;

    // NOTE: Assumption is made that asset2 is the yield-bearing counterpart of asset0 and asset1.
    //       Examples: asset0 = USDC, asset1 = DAI, asset2 = sDAI
    IERC20 public override immutable asset0;
    IERC20 public override immutable asset1;
    IERC20 public override immutable asset2;

    address public override immutable rateProvider;

    uint256 public override totalShares;

    mapping(address user => uint256 shares) public override shares;

    constructor(address asset0_, address asset1_, address asset2_, address rateProvider_) {
        require(asset0_       != address(0), "PSM3/invalid-asset0");
        require(asset1_       != address(0), "PSM3/invalid-asset1");
        require(asset2_       != address(0), "PSM3/invalid-asset2");
        require(rateProvider_ != address(0), "PSM3/invalid-rateProvider");

        require(asset0_ != asset1_, "PSM3/asset0-asset1-same");
        require(asset0_ != asset2_, "PSM3/asset0-asset2-same");
        require(asset1_ != asset2_, "PSM3/asset1-asset2-same");

        asset0 = IERC20(asset0_);
        asset1 = IERC20(asset1_);
        asset2 = IERC20(asset2_);

        rateProvider = rateProvider_;

        require(
            IRateProviderLike(rateProvider_).getConversionRate() != 0,
            "PSM3/rate-provider-returns-zero"
        );

        _asset0Precision = 10 ** IERC20(asset0_).decimals();
        _asset1Precision = 10 ** IERC20(asset1_).decimals();
        _asset2Precision = 10 ** IERC20(asset2_).decimals();
    }

    /**********************************************************************************************/
    /*** Swap functions                                                                         ***/
    /**********************************************************************************************/

    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    )
        external override returns (uint256 amountOut)
    {
        require(amountIn != 0,          "PSM3/invalid-amountIn");
        require(receiver != address(0), "PSM3/invalid-receiver");

        amountOut = previewSwapExactIn(assetIn, assetOut, amountIn);

        require(amountOut >= minAmountOut, "PSM3/amountOut-too-low");

        IERC20(assetIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(assetOut).safeTransfer(receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    )
        external override returns (uint256 amountIn)
    {
        require(amountOut != 0,         "PSM3/invalid-amountOut");
        require(receiver != address(0), "PSM3/invalid-receiver");

        amountIn = previewSwapExactOut(assetIn, assetOut, amountOut);

        require(amountIn <= maxAmountIn, "PSM3/amountIn-too-high");

        IERC20(assetIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(assetOut).safeTransfer(receiver, amountOut);

        emit Swap(assetIn, assetOut, msg.sender, receiver, amountIn, amountOut, referralCode);
    }

    /**********************************************************************************************/
    /*** Liquidity provision functions                                                          ***/
    /**********************************************************************************************/

    function deposit(address asset, address receiver, uint256 assetsToDeposit)
        external override returns (uint256 newShares)
    {
        require(assetsToDeposit != 0, "PSM3/invalid-amount");

        newShares = previewDeposit(asset, assetsToDeposit);

        shares[receiver] += newShares;
        totalShares      += newShares;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assetsToDeposit);

        emit Deposit(asset, msg.sender, receiver, assetsToDeposit, newShares);
    }

    function withdraw(address asset, address receiver, uint256 maxAssetsToWithdraw)
        external override returns (uint256 assetsWithdrawn)
    {
        require(maxAssetsToWithdraw != 0, "PSM3/invalid-amount");

        uint256 sharesToBurn;

        ( sharesToBurn, assetsWithdrawn ) = previewWithdraw(asset, maxAssetsToWithdraw);

        // `previewWithdraw` ensures that `sharesToBurn` <= `shares[msg.sender]`
        unchecked {
            shares[msg.sender] -= sharesToBurn;
            totalShares        -= sharesToBurn;
        }

        IERC20(asset).safeTransfer(receiver, assetsWithdrawn);

        emit Withdraw(asset, msg.sender, receiver, assetsWithdrawn, sharesToBurn);
    }

    /**********************************************************************************************/
    /*** Deposit/withdraw preview functions                                                     ***/
    /**********************************************************************************************/

    function previewDeposit(address asset, uint256 assetsToDeposit)
        public view override returns (uint256)
    {
        require(_isValidAsset(asset), "PSM3/invalid-asset");

        // Convert amount to 1e18 precision denominated in value of asset0 then convert to shares.
        return convertToShares(_getAssetValue(asset, assetsToDeposit, false));  // Round down
    }

    function previewWithdraw(address asset, uint256 maxAssetsToWithdraw)
        public view override returns (uint256 sharesToBurn, uint256 assetsWithdrawn)
    {
        require(_isValidAsset(asset), "PSM3/invalid-asset");

        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        assetsWithdrawn = assetBalance < maxAssetsToWithdraw
            ? assetBalance
            : maxAssetsToWithdraw;

        // Get shares to burn, rounding up for both calculations
        sharesToBurn = _convertToSharesRoundUp(_getAssetValue(asset, assetsWithdrawn, true));

        uint256 userShares = shares[msg.sender];

        if (sharesToBurn > userShares) {
            assetsWithdrawn = convertToAssets(asset, userShares);
            sharesToBurn    = userShares;
        }
    }

    /**********************************************************************************************/
    /*** Swap preview functions                                                                 ***/
    /**********************************************************************************************/

    function previewSwapExactIn(address assetIn, address assetOut, uint256 amountIn)
        public view override returns (uint256 amountOut)
    {
        // Round down to get amountOut
        amountOut = _getSwapQuote(assetIn, assetOut, amountIn, false);
    }

    function previewSwapExactOut(address assetIn, address assetOut, uint256 amountOut)
        public view override returns (uint256 amountIn)
    {
        // Round up to get amountIn
        amountIn = _getSwapQuote(assetOut, assetIn, amountOut, true);
    }

    /**********************************************************************************************/
    /*** Conversion functions                                                                   ***/
    /**********************************************************************************************/

    function convertToAssets(address asset, uint256 numShares)
        public view override returns (uint256)
    {
        require(_isValidAsset(asset), "PSM3/invalid-asset");

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
            return numShares * totalAssets() / totalShares_;
        }
        return numShares;
    }

    function convertToShares(uint256 assetValue) public view override returns (uint256) {
        uint256 totalAssets_ = totalAssets();
        if (totalAssets_ != 0) {
            return assetValue * totalShares / totalAssets_;
        }
        return assetValue;
    }

    function convertToShares(address asset, uint256 assets) public view override returns (uint256) {
        require(_isValidAsset(asset), "PSM3/invalid-asset");
        return convertToShares(_getAssetValue(asset, assets, false));  // Round down
    }

    /**********************************************************************************************/
    /*** Asset value functions                                                                  ***/
    /**********************************************************************************************/

    function totalAssets() public view override returns (uint256) {
        return _getAsset0Value(asset0.balanceOf(address(this)))
            +  _getAsset1Value(asset1.balanceOf(address(this)))
            +  _getAsset2Value(asset2.balanceOf(address(this)), false);  // Round down
    }

    /**********************************************************************************************/
    /*** Internal valuation functions (deposit/withdraw)                                        ***/
    /**********************************************************************************************/

    function _getAssetValue(address asset, uint256 amount, bool roundUp) internal view returns (uint256) {
        if      (asset == address(asset0)) return _getAsset0Value(amount);
        else if (asset == address(asset1)) return _getAsset1Value(amount);
        else if (asset == address(asset2)) return _getAsset2Value(amount, roundUp);
        else revert("PSM3/invalid-asset");
    }

    function _getAsset0Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / _asset0Precision;
    }

    function _getAsset1Value(uint256 amount) internal view returns (uint256) {
        return amount * 1e18 / _asset1Precision;
    }

    function _getAsset2Value(uint256 amount, bool roundUp) internal view returns (uint256) {
        // NOTE: Multiplying by 1e18 and dividing by 1e27 cancels to 1e9 in denominator
        if (!roundUp) return amount
            * IRateProviderLike(rateProvider).getConversionRate()
            / 1e9
            / _asset2Precision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * IRateProviderLike(rateProvider).getConversionRate(), 1e9),
            _asset2Precision
        );
    }

    /**********************************************************************************************/
    /*** Internal preview functions (swaps)                                                     ***/
    /**********************************************************************************************/

    function _getSwapQuote(address asset, address quoteAsset, uint256 amount, bool roundUp)
        internal view returns (uint256 quoteAmount)
    {
        if (asset == address(asset0)) {
            if      (quoteAsset == address(asset1)) return _convertOneToOne(amount, _asset0Precision, _asset1Precision, roundUp);
            else if (quoteAsset == address(asset2)) return _convertToAsset2(amount, _asset0Precision, roundUp);
        }

        else if (asset == address(asset1)) {
            if      (quoteAsset == address(asset0)) return _convertOneToOne(amount, _asset1Precision, _asset0Precision, roundUp);
            else if (quoteAsset == address(asset2)) return _convertToAsset2(amount, _asset1Precision, roundUp);
        }

        else if (asset == address(asset2)) {
            if      (quoteAsset == address(asset0)) return _convertFromAsset2(amount, _asset0Precision, roundUp);
            else if (quoteAsset == address(asset1)) return _convertFromAsset2(amount, _asset1Precision, roundUp);
        }

        revert("PSM3/invalid-asset");
    }

    function _convertToAsset2(uint256 amount, uint256 assetPrecision, bool roundUp)
        internal view returns (uint256)
    {
        uint256 rate = IRateProviderLike(rateProvider).getConversionRate();

        if (!roundUp) return amount * 1e27 / rate * _asset2Precision / assetPrecision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * 1e27, rate) * _asset2Precision,
            assetPrecision
        );
    }

    function _convertFromAsset2(uint256 amount, uint256 assetPrecision, bool roundUp)
        internal view returns (uint256)
    {
        uint256 rate = IRateProviderLike(rateProvider).getConversionRate();

        if (!roundUp) return amount * rate / 1e27 * assetPrecision / _asset2Precision;

        return Math.ceilDiv(
            Math.ceilDiv(amount * rate, 1e27) * assetPrecision,
            _asset2Precision
        );
    }

    function _convertOneToOne(
        uint256 amount,
        uint256 assetPrecision,
        uint256 convertAssetPrecision,
        bool roundUp
    )
        internal pure returns (uint256)
    {
        if (!roundUp) return amount * convertAssetPrecision / assetPrecision;

        return Math.ceilDiv(amount * convertAssetPrecision, assetPrecision);
    }

    /**********************************************************************************************/
    /*** Internal helper functions                                                              ***/
    /**********************************************************************************************/

    function _convertToSharesRoundUp(uint256 assetValue) internal view returns (uint256) {
        uint256 totalValue = totalAssets();
        if (totalValue != 0) {
            return Math.ceilDiv(assetValue * totalShares, totalValue);
        }
        return assetValue;
    }

    function _isValidAsset(address asset) internal view returns (bool) {
        return asset == address(asset0) || asset == address(asset1) || asset == address(asset2);
    }

}
